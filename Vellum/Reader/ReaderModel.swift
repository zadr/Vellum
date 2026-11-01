import Foundation
import Observation

/// A book being read: its pages for the current screen and text settings, and which one is showing.
@Observable
final class ReaderModel {
	let book: ReaderBook

	private(set) var layout: BookLayout?
	private(set) var isLayingOut = false
	private(set) var layoutError: String?
	var isChromeVisible = false
	/// A web or mail link the reader tapped, for the view to open.
	var externalLink: URL?
	/// A page the reader asked to go to, such as from a link or the contents. Scroll mode moves there when it changes;
	/// page mode follows `visiblePage` directly. The number makes repeated jumps to the same page distinct.
	private(set) var jump: (page: Int, number: Int)?
	/// Where the reader was before following links in the book, most recent last, so they can go back.
	private(set) var backStack: [Int] = []

	/// The page scrolled into view. Optional because that's what scroll positions bind to.
	/// Set by the reader's own page turns and by the page scroller. Only movements the reader makes are saved; the
	/// scroller also reports pages as it settles after a relayout, and those mustn't replace the saved place.
	var visiblePage: Int?

	/// Where the reader is. Only changes when they move, so laying the book out again never loses their place.
	@ObservationIgnored private var position: ReadingPosition
	/// Where each scroll piece on screen starts, relative to the top of the scroll view.
	@ObservationIgnored private var pieceTops: [Int: Double] = [:]
	/// Where a piece scrolled to the top of the screen sits, in the same terms as `pieceTops`.
	@ObservationIgnored var scrollTopEdge = 0.0
	@ObservationIgnored private var layoutGeneration = 0
	@ObservationIgnored private let onPositionChange: (ReadingPosition) -> Void

	init(book: ReaderBook, position: ReadingPosition?, onPositionChange: @escaping (ReadingPosition) -> Void) {
		self.book = book
		self.position = position ?? ReadingPosition(chapter: 0, progression: 0)
		self.onPositionChange = onPositionChange
	}


	var currentPage: Int {
		visiblePage ?? 0
	}

	var chapter: Int {
		layout?.pages[safe: currentPage]?.chapter ?? position.chapter
	}

	/// The page number within the current chapter, starting at 1.
	var pageInChapter: Int {
		guard let layout, layout.chapterStarts.indices.contains(chapter) else { return 1 }
		return currentPage - layout.chapterStarts[chapter] + 1
	}

	var pagesInChapter: Int {
		guard let layout, layout.chapterStarts.indices.contains(chapter) else { return 1 }
		return layout.pageCount(inChapter: chapter)
	}

	/// How far through the current chapter the reader is, from 0 to 1.
	var fractionOfChapterRead: Double {
		Double(pageInChapter) / Double(pagesInChapter)
	}

	var fractionRead: Double {
		guard let layout, !layout.pages.isEmpty else { return 0 }
		return Double(currentPage + 1) / Double(layout.pages.count)
	}

	// MARK: Turning pages

	func nextPage() {
		guard let layout else { return }
		visiblePage = min(currentPage + 1, layout.pages.count - 1)
		readerMoved()
	}

	func previousPage() {
		visiblePage = max(currentPage - 1, 0)
		readerMoved()
	}

	func toggleChrome() {
		isChromeVisible.toggle()
	}

	/// Follows a link: within the book it jumps there, remembering where the reader was; otherwise the view opens it.
	func follow(_ link: URL) {
		guard let layout else { return }

		if let destination = book.destination(of: link) {
			backStack.append(currentPage)
			jump(to: layout.pageIndex(forChapter: destination.chapter, fragment: destination.fragment))
		} else if !link.isFileURL {
			externalLink = link
		}
	}

	func goBack() {
		guard let page = backStack.popLast() else { return }
		jump(to: page)
	}

	private func jump(to page: Int) {
		visiblePage = page
		jump = (page, (jump?.number ?? 0) + 1)
		readerMoved()
	}

	func go(to entry: ReaderContentsEntry) {
		guard let layout else { return }
		jump(to: layout.pageIndex(for: entry))
	}

	// MARK: Scrolling

	/// The piece to scroll to when a scrolling layout appears, and how far down it the saved line is.
	var scrollRestoreTarget: (piece: Int, y: Double) {
		guard let layout else { return (0, 0) }

		let piece = layout.pageIndex(for: position)
		let y = position.offset.map { layout.y(ofCharacter: $0, inPage: piece) } ?? 0
		return (piece, y)
	}

	func scrollPiece(_ index: Int, movedTo top: Double) {
		pieceTops[index] = top
	}

	func scrollPieceDisappeared(_ index: Int) {
		pieceTops[index] = nil
	}

	func pieceTop(_ index: Int) -> Double? {
		pieceTops[index]
	}

	/// The reader swiped to a page, in page mode. Called when the swipe settles.
	func swipeEnded() {
		guard layout?.mode == .pages else { return }
		readerMoved()
	}

	/// Records the line at the top of the screen once scrolling the reader did comes to rest.
	func scrollingStopped() {
		guard let layout, layout.isComplete, layout.mode == .scroll else { return }

		// The piece crossing the top edge of the screen.
		let edge = scrollTopEdge + 0.5
		let crossing = pieceTops
			.filter { index, top in layout.pages.indices.contains(index) && top <= edge && top + layout.pages[index].height > edge }
			.max { $0.value < $1.value }
		guard let (piece, top) = crossing else { return }

		let offset = layout.characterOffset(inPage: piece, atY: scrollTopEdge - top)
		visiblePage = piece
		save(layout.position(forPage: piece, offset: offset))
	}

	// MARK: Layout

	/// Breaks the book into pages for a page size, typography, and mode, keeping the reader's place.
	func layOut(pageSize: CGSize, typography: ReaderTypography, mode: ReaderMode) async {
		guard pageSize.width > 0, pageSize.height > 0 else { return }

		layoutGeneration += 1
		let generation = layoutGeneration
		isLayingOut = true

		do {
			// Show the chapter being read right away, so changing a setting updates the page while it's being changed.
			let chapter = min(max(position.chapter, 0), max(book.chapters.count - 1, 0))
			show(try await BookLayout.make(book: book, pageSize: pageSize, typography: typography, mode: mode, onlyChapter: chapter))

			// Wait for the setting to stop changing before doing the rest of the book.
			try await Task.sleep(for: .milliseconds(300))
			show(try await BookLayout.make(book: book, pageSize: pageSize, typography: typography, mode: mode))
			layoutError = nil
		} catch is CancellationError {
			// A newer layout replaced this one.
		} catch {
			layoutError = error.localizedDescription
		}

		if generation == layoutGeneration {
			isLayingOut = false
		}
	}

	private func show(_ newLayout: BookLayout) {
		pieceTops = [:]
		// Page numbers mean something different in a new layout.
		backStack = []
		layout = newLayout
		visiblePage = newLayout.pageIndex(for: position)
	}

	/// The reader turned a page, or jumped somewhere in either mode. Scrolling is recorded once it stops.
	private func readerMoved() {
		guard let layout, layout.isComplete, let visiblePage, layout.pages.indices.contains(visiblePage) else { return }

		// Staying on the saved page, as a swipe that springs back does, keeps the exact saved spot.
		if layout.pageIndex(for: position) == visiblePage {
			return
		}
		save(layout.position(forPage: visiblePage))
	}

	private func save(_ newPosition: ReadingPosition) {
		position = newPosition
		onPositionChange(newPosition)
	}
}
