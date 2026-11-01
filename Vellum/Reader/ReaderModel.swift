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

	/// The page scrolled into view. Optional because that's what scroll positions bind to.
	var visiblePage: Int? {
		didSet { recordPosition() }
	}

	@ObservationIgnored private var position: ReadingPosition
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

	var fractionRead: Double {
		guard let layout, !layout.pages.isEmpty else { return 0 }
		return Double(currentPage + 1) / Double(layout.pages.count)
	}

	// MARK: Turning pages

	func nextPage() {
		guard let layout else { return }
		visiblePage = min(currentPage + 1, layout.pages.count - 1)
	}

	func previousPage() {
		visiblePage = max(currentPage - 1, 0)
	}

	func toggleChrome() {
		isChromeVisible.toggle()
	}

	func go(to entry: ReaderContentsEntry) {
		guard let layout else { return }
		visiblePage = layout.pageIndex(for: entry)
	}

	// MARK: Layout

	/// Breaks the book into pages for a page size and typography, keeping the reader's place.
	func layOut(pageSize: CGSize, typography: ReaderTypography) async {
		guard pageSize.width > 0, pageSize.height > 0 else { return }

		layoutGeneration += 1
		let generation = layoutGeneration
		isLayingOut = true

		do {
			let newLayout = try await BookLayout.make(book: book, pageSize: pageSize, typography: typography)
			layout = newLayout
			visiblePage = newLayout.pageIndex(for: position)
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

	private func recordPosition() {
		guard let layout, let visiblePage, layout.pages.indices.contains(visiblePage) else { return }

		position = layout.position(forPage: visiblePage)
		position.fractionRead = Double(visiblePage + 1) / Double(layout.pages.count)
		position.lastRead = .now
		onPositionChange(position)
	}
}
