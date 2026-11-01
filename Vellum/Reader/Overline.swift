import CoreGraphics
import CoreText
import Foundation

nonisolated enum Overline {
	/// Draws a line over the overlined runs of a line, at the top of their capitals.
	static func draw(in line: CTLine, at origin: CGPoint, context: CGContext) {
		for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
			let attributes = CTRunGetAttributes(run) as NSDictionary
			guard attributes[ChapterConverter.overlineAttribute.rawValue] != nil, let font = attributes[kCTFontAttributeName] else { continue }

			let ctFont = font as! CTFont
			let start = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
			let width = CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
			let thickness = max(CTFontGetUnderlineThickness(ctFont), 1)
			context.fill(CGRect(x: origin.x + start, y: origin.y + CTFontGetAscent(ctFont) - thickness, width: width, height: thickness))
		}
	}
}
