import Foundation

/// A letter the book floats to the left of a paragraph's first lines, sized and spaced as its styles say.
nonisolated final class DropCapStyle: @unchecked Sendable {
	/// The letter's size relative to the paragraph's text.
	let scale: Double
	/// The letter's line height as a multiple of its own size, or `nil` for the font's natural height.
	let lineHeight: Double?
	/// Margins around the letter, in multiples of its own size.
	let marginTop: Double
	let marginRight: Double
	let marginBottom: Double
	/// Sized to the letter's glyphs instead of its line height. WebKit, and so Apple Books, which books are designed
	/// for, does this for a floated `::first-letter`.
	var fitsGlyphs = false

	init(scale: Double, lineHeight: Double?, marginTop: Double, marginRight: Double, marginBottom: Double) {
		self.scale = scale
		self.lineHeight = lineHeight
		self.marginTop = marginTop
		self.marginRight = marginRight
		self.marginBottom = marginBottom
	}

	/// The drop cap a style describes: any letter floated left, as CSS floats it whatever its size.
	convenience init?(_ style: CSSStyle) {
		guard style.floatsLeft == true else { return nil }

		let scale = style.fontScale ?? 1
		func em(_ property: String) -> Double {
			guard let length = style.length(property) else { return 0 }
			// Lengths in ems are relative to the letter's own size; points are converted at the 16-pixel default.
			return length.unit == .em ? length.value : length.points(fontSize: 1, width: 0) / 16 / scale
		}

		var lineHeight: Double?
		if let value = style.properties["line-height"]?.lowercased() {
			if let number = Double(value) {
				lineHeight = number
			} else if let length = CSSLength(value) {
				lineHeight = length.unit == .percent ? length.value / 100 : em("line-height")
			}
		}

		self.init(scale: scale, lineHeight: lineHeight, marginTop: em("margin-top") + em("padding-top"), marginRight: em("margin-right") + em("padding-right"), marginBottom: em("margin-bottom") + em("padding-bottom"))
	}
}
