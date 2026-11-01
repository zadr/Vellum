import CoreGraphics
import CoreText
import Foundation

nonisolated enum Strikethrough {
	/// Draws a line through the struck-through runs of a line, at the height of a lowercase letter's middle.
	static func draw(in line: CTLine, at origin: CGPoint, context: CGContext) {
		for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
			let attributes = CTRunGetAttributes(run) as NSDictionary
			guard attributes[ChapterConverter.strikethroughAttribute.rawValue] != nil, let font = attributes[kCTFontAttributeName] else { continue }

			let start = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
			let width = CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
			let ctFont = font as! CTFont
			let thickness = max(CTFontGetUnderlineThickness(ctFont), 1)
			context.fill(CGRect(x: origin.x + start, y: origin.y + CTFontGetXHeight(ctFont) / 2 - thickness / 2, width: width, height: thickness))
		}
	}
}
