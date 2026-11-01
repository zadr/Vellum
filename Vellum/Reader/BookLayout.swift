import CoreGraphics
import CoreText
import Foundation

/// A whole book set into lines and broken into pages for one page size, typography, and reading mode.
/// In scroll mode the "pages" are screen-sized pieces of text that stack seamlessly, each trimmed to the lines it holds.
nonisolated final class BookLayout: @unchecked Sendable {
	struct Page: Sendable {
		let chapter: Int
		/// The page's text, as a range in its chapter's text.
		let location: Int
		let length: Int
		/// How tall the page is drawn. Every page is a screen tall, except pieces in scroll mode.
		let height: Double
		/// The chapter's first line on this page.
		let firstLine: Int
		/// Where the top of each of the page's lines sits, measured down from the top of the page.
		let lineTops: [Double]
	}

	private struct Chapter {
		let text: NSAttributedString
		let lines: [TypesetLine]
		let anchors: [String: Int]
	}

	let mode: ReaderMode
	let pageSize: CGSize
	/// False for a quick layout of one chapter, where every other chapter is a single empty page.
	let isComplete: Bool
	let pages: [Page]
	/// The index of each chapter's first page.
	let chapterStarts: [Int]

	private let textRect: CGRect
	private let chapters: [Chapter]

	private init(mode: ReaderMode, pageSize: CGSize, isComplete: Bool, textRect: CGRect, pages: [Page], chapterStarts: [Int], chapters: [Chapter]) {
		self.mode = mode
		self.pageSize = pageSize
		self.isComplete = isComplete
		self.textRect = textRect
		self.pages = pages
		self.chapterStarts = chapterStarts
		self.chapters = chapters
	}

	/// Converts, sets, and paginates every chapter, or just one for a quick preview while settings change.
	/// Runs off the main actor; checks for cancellation between chapters.
	@concurrent
	static func make(book: ReaderBook, pageSize: CGSize, typography: ReaderTypography, mode: ReaderMode, onlyChapter: Int? = nil) async throws -> BookLayout {
		let textRect = typography.textRect(in: pageSize, mode: mode)
		let typesetter = ParagraphTypesetter(width: textRect.width)
		let styleSheets = StyleSheetCache(bookRoot: book.root)

		var pages = [Page]()
		var chapterStarts = [Int]()
		var chapters = [Chapter]()

		for index in book.chapters.indices {
			try Task.checkCancellation()
			chapterStarts.append(pages.count)

			if let onlyChapter, index != onlyChapter {
				chapters.append(Chapter(text: NSAttributedString(), lines: [], anchors: [:]))
				pages.append(Page(chapter: index, location: 0, length: 0, height: pageSize.height, firstLine: 0, lineTops: []))
				continue
			}

			let output = ChapterConverter.convert(book.fileURL(forChapter: index), typography: typography, textArea: textRect.size, styleSheets: styleSheets)
			let lines = typesetter.lines(for: output.text)
			pages += paginate(lines, chapter: index, textLength: output.text.length, textRect: textRect, pageSize: pageSize, mode: mode)
			chapters.append(Chapter(text: output.text, lines: lines, anchors: output.anchors))
		}

		return BookLayout(mode: mode, pageSize: pageSize, isComplete: onlyChapter == nil, textRect: textRect, pages: pages, chapterStarts: chapterStarts, chapters: chapters)
	}

	/// Stacks a chapter's lines onto pages. Paragraph spacing is dropped at the top of a page, but kept between
	/// scroll pieces so they join seamlessly.
	private static func paginate(_ lines: [TypesetLine], chapter: Int, textLength: Int, textRect: CGRect, pageSize: CGSize, mode: ReaderMode) -> [Page] {
		var pages = [Page]()
		var first = 0
		var tops = [Double]()
		var y = 0.0

		func finishPage(at end: Int) {
			let location = pages.isEmpty ? 0 : lines[first].location
			let pageEnd = end < lines.count ? lines[end].location : textLength
			var lineTops = tops.map { $0 + textRect.minY }

			// A page holding only an image, like a cover or a map, looks best centered.
			if mode == .pages, lineTops.count == 1, !ImageRun.images(in: lines[first].line).isEmpty {
				lineTops[0] = textRect.minY + max((textRect.height - lines[first].totalHeight) / 2, 0)
			}

			let height = mode == .pages ? pageSize.height : max((textRect.minY + y).rounded(.up), 1)
			pages.append(Page(chapter: chapter, location: location, length: max(pageEnd - location, 0), height: height, firstLine: first, lineTops: lineTops))
		}

		for (index, line) in lines.enumerated() {
			var gap = index == first && mode == .pages ? 0 : line.spaceBefore
			// Lines a drop cap spans have to fit on the same page as it.
			let needed = lines[index...].prefix(line.keepWithNext + 1).reduce(0) { $0 + $1.totalHeight }

			if index > first, (mode == .pages && line.breaksPageBefore) || y + gap + needed > textRect.height {
				finishPage(at: index)
				first = index
				tops = []
				y = 0
				gap = mode == .pages ? 0 : line.spaceBefore
			}

			tops.append(y + gap)
			y += gap + line.totalHeight
		}

		if lines.isEmpty {
			pages.append(Page(chapter: chapter, location: 0, length: textLength, height: mode == .pages ? pageSize.height : 1, firstLine: 0, lineTops: []))
		} else {
			finishPage(at: lines.count)
		}
		return pages
	}

	// MARK: Finding pages

	func pageCount(inChapter chapter: Int) -> Int {
		let end = chapter + 1 < chapterStarts.count ? chapterStarts[chapter + 1] : pages.count
		return end - chapterStarts[chapter]
	}

	func isChapterStart(_ index: Int) -> Bool {
		chapterStarts.contains(index)
	}

	func pageIndex(for position: ReadingPosition) -> Int {
		guard !chapterStarts.isEmpty else { return 0 }

		let chapter = min(max(position.chapter, 0), chapterStarts.count - 1)
		if let offset = position.offset {
			return pageIndex(forChapter: chapter, offset: offset)
		}

		let count = pageCount(inChapter: chapter)
		let page = min(Int((position.progression * Double(count)).rounded()), count - 1)
		return chapterStarts[chapter] + max(page, 0)
	}

	/// The page holding a character of a chapter.
	func pageIndex(forChapter chapter: Int, offset: Int) -> Int {
		let start = chapterStarts[chapter]
		let pageRange = start..<(start + pageCount(inChapter: chapter))
		return pageRange.last { pages[$0].location <= offset } ?? start
	}

	/// A position at a character of the page, defaulting to the page's first character.
	func position(forPage index: Int, offset: Int? = nil) -> ReadingPosition {
		let page = pages[index]
		let progression = Double(index - chapterStarts[page.chapter]) / Double(pageCount(inChapter: page.chapter))
		return ReadingPosition(
			chapter: page.chapter,
			progression: progression,
			fractionRead: Double(index + 1) / Double(pages.count),
			lastRead: .now,
			offset: offset ?? page.location
		)
	}

	/// The first character on the line at a distance from the top of a page.
	func characterOffset(inPage index: Int, atY y: Double) -> Int {
		let page = pages[index]
		let lines = chapters[page.chapter].lines

		for (line, top) in zip(lines[page.firstLine...], page.lineTops) where top + line.totalHeight > y {
			return line.location
		}
		return page.location + page.length
	}

	/// How far from the top of a page the line holding a character starts.
	func y(ofCharacter offset: Int, inPage index: Int) -> Double {
		let page = pages[index]
		let lines = chapters[page.chapter].lines
		let placed = Array(zip(lines[page.firstLine...], page.lineTops))
		return placed.last { $0.0.location <= offset }?.1 ?? 0
	}

	func pageIndex(for entry: ReaderContentsEntry) -> Int {
		guard chapters.indices.contains(entry.chapter) else { return 0 }
		guard let fragment = entry.fragment, let offset = chapters[entry.chapter].anchors[fragment] else { return chapterStarts[entry.chapter] }
		return pageIndex(forChapter: entry.chapter, offset: offset)
	}

	/// The words on a page, for VoiceOver.
	func text(ofPage index: Int) -> String {
		let page = pages[index]
		return chapters[page.chapter].text
			.attributedSubstring(from: NSRange(location: page.location, length: page.length))
			.string
			.replacing("\u{FFFC}", with: "")
	}

	// MARK: Drawing

	/// Draws a page into a context the page's size, with the origin at the top left as SwiftUI's are.
	func draw(page index: Int, in context: CGContext, textColor: CGColor) {
		let page = pages[index]
		let lines = chapters[page.chapter].lines

		context.saveGState()
		defer { context.restoreGState() }

		// Core Text draws with the origin at the bottom left.
		context.translateBy(x: 0, y: page.height)
		context.scaleBy(x: 1, y: -1)
		context.textMatrix = .identity
		context.setFillColor(textColor)

		for (line, boxTop) in zip(lines[page.firstLine...], page.lineTops) {
			drawBorders(of: line, boxTop: boxTop, pageHeight: page.height, context: context)

			let top = boxTop + line.spaceAboveText
			for cell in line.cells {
				let cellOrigin = CGPoint(x: textRect.minX + line.x + cell.x, y: page.height - (top + cell.baseline))
				context.textPosition = cellOrigin
				CTLineDraw(cell.line, context)
				Strikethrough.draw(in: cell.line, at: cellOrigin, context: context)
			}

			let origin = CGPoint(x: textRect.minX + line.x, y: page.height - (top + line.height - line.descent))
			context.textPosition = origin
			CTLineDraw(line.line, context)
			ImageRun.draw(in: line.line, at: origin, context: context)
			Strikethrough.draw(in: line.line, at: origin, context: context)

			if let dropCap = line.dropCap {
				context.textPosition = CGPoint(x: textRect.minX + dropCap.x, y: page.height - (top + dropCap.baseline))
				CTLineDraw(dropCap.line, context)
			}
		}
	}

	/// Draws a line's rules, in the flipped, bottom-left-origin coordinates `draw` sets up.
	private func drawBorders(of line: TypesetLine, boxTop: Double, pageHeight: Double, context: CGContext) {
		let left = textRect.minX + line.paragraphIndent
		let width = line.paragraphWidth

		if line.borderTop > 0 {
			context.fill(CGRect(x: left, y: pageHeight - boxTop - line.borderTop, width: width, height: line.borderTop))
		}
		if line.borderBottom > 0 {
			let bottom = boxTop + line.totalHeight
			context.fill(CGRect(x: left, y: pageHeight - bottom, width: width, height: line.borderBottom))
		}
		if line.borderLeft > 0 {
			// Beside the text, in the paragraph's left margin, spanning the whole line so bars join up.
			context.fill(CGRect(x: left - line.borderLeft - TypesetLine.ruleGap, y: pageHeight - boxTop - line.totalHeight, width: line.borderLeft, height: line.totalHeight))
		}
	}
}
