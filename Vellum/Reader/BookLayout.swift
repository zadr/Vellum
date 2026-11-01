import CoreGraphics
import CoreText
import Foundation

/// A whole book broken into pages for one page size and typography. Each chapter starts on a new page.
nonisolated final class BookLayout: @unchecked Sendable {
	struct Page: Sendable {
		let chapter: Int
		/// The page's text, as a range in its chapter's text.
		let location: Int
		let length: Int
	}

	private struct Chapter {
		let text: NSAttributedString
		let framesetter: CTFramesetter
		let anchors: [String: Int]
	}

	let pageSize: CGSize
	let pages: [Page]
	/// The index of each chapter's first page.
	let chapterStarts: [Int]

	private let textRect: CGRect
	private let chapters: [Chapter]

	private init(pageSize: CGSize, textRect: CGRect, pages: [Page], chapterStarts: [Int], chapters: [Chapter]) {
		self.pageSize = pageSize
		self.textRect = textRect
		self.pages = pages
		self.chapterStarts = chapterStarts
		self.chapters = chapters
	}

	/// Converts and paginates every chapter. Runs off the main actor; checks for cancellation between chapters.
	@concurrent
	static func make(book: ReaderBook, pageSize: CGSize, typography: ReaderTypography) async throws -> BookLayout {
		let textRect = typography.textRect(in: pageSize)
		let path = CGPath(rect: textRect, transform: nil)
		let styleSheets = StyleSheetCache()

		var pages = [Page]()
		var chapterStarts = [Int]()
		var chapters = [Chapter]()

		for index in book.chapters.indices {
			try Task.checkCancellation()

			let output = ChapterConverter.convert(book.fileURL(forChapter: index), typography: typography, textArea: textRect.size, styleSheets: styleSheets)
			let framesetter = CTFramesetterCreateWithAttributedString(output.text)
			chapterStarts.append(pages.count)

			var location = 0
			repeat {
				let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
				var length = CTFrameGetVisibleStringRange(frame).length

				// Something too big to fit on any page would otherwise stop pagination; skip past it.
				if length == 0 {
					length = min(1, output.text.length - location)
				}

				pages.append(Page(chapter: index, location: location, length: length))
				location += length
			} while location < output.text.length

			chapters.append(Chapter(text: output.text, framesetter: framesetter, anchors: output.anchors))
		}

		return BookLayout(pageSize: pageSize, textRect: textRect, pages: pages, chapterStarts: chapterStarts, chapters: chapters)
	}

	// MARK: Finding pages

	func pageCount(inChapter chapter: Int) -> Int {
		let end = chapter + 1 < chapterStarts.count ? chapterStarts[chapter + 1] : pages.count
		return end - chapterStarts[chapter]
	}

	func pageIndex(for position: ReadingPosition) -> Int {
		guard !chapterStarts.isEmpty else { return 0 }

		let chapter = min(max(position.chapter, 0), chapterStarts.count - 1)
		let count = pageCount(inChapter: chapter)
		let offset = min(Int((position.progression * Double(count)).rounded()), count - 1)
		return chapterStarts[chapter] + max(offset, 0)
	}

	func position(forPage index: Int) -> ReadingPosition {
		let chapter = pages[index].chapter
		let progression = Double(index - chapterStarts[chapter]) / Double(pageCount(inChapter: chapter))
		return ReadingPosition(chapter: chapter, progression: progression)
	}

	func pageIndex(for entry: ReaderContentsEntry) -> Int {
		guard chapters.indices.contains(entry.chapter) else { return 0 }

		let start = chapterStarts[entry.chapter]
		guard let fragment = entry.fragment, let offset = chapters[entry.chapter].anchors[fragment] else { return start }

		let pageRange = start..<(start + pageCount(inChapter: entry.chapter))
		return pageRange.last { pages[$0].location <= offset } ?? start
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

	/// Draws a page into a context whose origin is at the top left, as SwiftUI's are.
	func draw(page index: Int, in context: CGContext, textColor: CGColor) {
		let page = pages[index]
		let chapter = chapters[page.chapter]
		let path = CGPath(rect: textRect, transform: nil)
		let frame = CTFramesetterCreateFrame(chapter.framesetter, CFRange(location: page.location, length: page.length), path, nil)

		context.saveGState()
		defer { context.restoreGState() }

		// Core Text draws with the origin at the bottom left.
		context.translateBy(x: 0, y: pageSize.height)
		context.scaleBy(x: 1, y: -1)
		context.textMatrix = .identity
		context.setFillColor(textColor)

		let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
		var origins = [CGPoint](repeating: .zero, count: lines.count)
		CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

		// A page holding only an image, like a cover or a map, looks best centered.
		if lines.count == 1, let image = images(in: lines[0]).first {
			context.translateBy(x: 0, y: -(textRect.height - image.run.size.height) / 2)
		}

		CTFrameDraw(frame, context)
		drawImages(in: lines, origins: origins, context: context)
	}

	private func images(in line: CTLine) -> [(run: ImageRun, offset: Double)] {
		(CTLineGetGlyphRuns(line) as? [CTRun] ?? []).compactMap { run in
			let attributes = CTRunGetAttributes(run) as NSDictionary
			guard let image = attributes[ChapterConverter.imageAttribute.rawValue] as? ImageRun else { return nil }
			return (image, CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil))
		}
	}

	private func drawImages(in lines: [CTLine], origins: [CGPoint], context: CGContext) {
		for (line, origin) in zip(lines, origins) {
			for image in images(in: line) {
				let rect = CGRect(x: textRect.minX + origin.x + image.offset, y: textRect.minY + origin.y, width: image.run.size.width, height: image.run.size.height)
				context.draw(image.run.image, in: rect)
			}
		}
	}
}
