import CoreGraphics
import CoreText
import Foundation

/// A whole book broken into pages for one page size, typography, and reading mode.
/// In scroll mode the "pages" are screen-sized pieces of text that stack seamlessly, each trimmed to the lines it holds.
nonisolated final class BookLayout: @unchecked Sendable {
	struct Page: Sendable {
		let chapter: Int
		/// The page's text, as a range in its chapter's text.
		let location: Int
		let length: Int
		/// How tall the page is drawn. Every page is a screen tall, except pieces in scroll mode.
		let height: Double
	}

	private struct Chapter {
		let text: NSAttributedString
		let framesetter: CTFramesetter
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

	/// Converts and paginates every chapter, or just one for a quick preview while settings change.
	/// Runs off the main actor; checks for cancellation between chapters.
	@concurrent
	static func make(book: ReaderBook, pageSize: CGSize, typography: ReaderTypography, mode: ReaderMode, onlyChapter: Int? = nil) async throws -> BookLayout {
		let textRect = typography.textRect(in: pageSize, mode: mode)
		let path = CGPath(rect: textRect, transform: nil)
		let styleSheets = StyleSheetCache()

		var pages = [Page]()
		var chapterStarts = [Int]()
		var chapters = [Chapter]()

		for index in book.chapters.indices {
			try Task.checkCancellation()

			if let onlyChapter, index != onlyChapter {
				let empty = NSAttributedString()
				chapterStarts.append(pages.count)
				pages.append(Page(chapter: index, location: 0, length: 0, height: pageSize.height))
				chapters.append(Chapter(text: empty, framesetter: CTFramesetterCreateWithAttributedString(empty), anchors: [:]))
				continue
			}

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

				let height = mode == .pages ? pageSize.height : usedHeight(of: frame, in: textRect)
				pages.append(Page(chapter: index, location: location, length: length, height: height))
				location += length
			} while location < output.text.length

			chapters.append(Chapter(text: output.text, framesetter: framesetter, anchors: output.anchors))
		}

		return BookLayout(mode: mode, pageSize: pageSize, isComplete: onlyChapter == nil, textRect: textRect, pages: pages, chapterStarts: chapterStarts, chapters: chapters)
	}

	/// How much of a frame, from its top, its lines actually fill.
	private static func usedHeight(of frame: CTFrame, in rect: CGRect) -> Double {
		let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
		guard let last = lines.last else { return 1 }

		var origins = [CGPoint](repeating: .zero, count: lines.count)
		CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

		var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
		CTLineGetTypographicBounds(last, &ascent, &descent, &leading)

		let bottom = (origins.last?.y ?? 0) - descent
		return max((rect.height - bottom).rounded(.up), 1)
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
		let line = lineGeometry(inPage: index).first { $0.bottom > y }
		return line?.location ?? page.location + page.length
	}

	/// How far from the top of a page the line holding a character starts.
	func y(ofCharacter offset: Int, inPage index: Int) -> Double {
		let line = lineGeometry(inPage: index).last { $0.location <= offset }
		return max(line?.top ?? 0, 0)
	}

	/// Where each line of a page sits, measured down from the top of the page as it's drawn.
	private func lineGeometry(inPage index: Int) -> [(location: Int, top: Double, bottom: Double)] {
		let page = pages[index]
		let frame = CTFramesetterCreateFrame(chapters[page.chapter].framesetter, CFRange(location: page.location, length: page.length), CGPath(rect: textRect, transform: nil), nil)
		let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
		var origins = [CGPoint](repeating: .zero, count: lines.count)
		CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

		// Matches the flip in `draw`: scroll pieces are aligned to the top of their frame.
		let top = mode == .scroll ? textRect.maxY : page.height

		return zip(lines, origins).map { line, origin in
			var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
			CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
			let baseline = top - (textRect.minY + origin.y)
			return (CTLineGetStringRange(line).location, baseline - ascent, baseline + descent)
		}
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
		let chapter = chapters[page.chapter]
		let path = CGPath(rect: textRect, transform: nil)
		let frame = CTFramesetterCreateFrame(chapter.framesetter, CFRange(location: page.location, length: page.length), path, nil)

		context.saveGState()
		defer { context.restoreGState() }

		// Core Text draws with the origin at the bottom left.
		context.translateBy(x: 0, y: page.height)
		context.scaleBy(x: 1, y: -1)
		context.textMatrix = .identity
		context.setFillColor(textColor)

		// A scroll piece is trimmed to its lines, so line its top up with the top of the frame.
		if mode == .scroll {
			context.translateBy(x: 0, y: page.height - textRect.maxY)
		}

		let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
		var origins = [CGPoint](repeating: .zero, count: lines.count)
		CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

		// A page holding only an image, like a cover or a map, looks best centered.
		if mode == .pages, lines.count == 1, let image = images(in: lines[0]).first {
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
