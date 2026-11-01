import CoreGraphics
import CoreText
import Foundation

nonisolated enum Highlight {
	/// Fills behind the runs of a line that have a background color, from just under the text to just over it.
	static func draw(in line: CTLine, at origin: CGPoint, context: CGContext) {
		for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
			let attributes = CTRunGetAttributes(run) as NSDictionary
			guard let color = attributes[ChapterConverter.highlightAttribute.rawValue] else { continue }

			var ascent: CGFloat = 0, descent: CGFloat = 0
			let width = CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), &ascent, &descent, nil)
			let start = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)

			context.saveGState()
			context.setFillColor(color as! CGColor)
			context.fill(CGRect(x: origin.x + start, y: origin.y - descent, width: width, height: ascent + descent))
			context.restoreGState()
		}
	}
}
