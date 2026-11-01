import Foundation

/// A CSS length like `1.5em`, `12px`, or `5%`.
nonisolated struct CSSLength: Sendable {
	enum Unit: Sendable {
		case em
		case points
		/// Of the containing block's width.
		case percent
	}

	var value: Double
	var unit: Unit

	init?(_ text: String) {
		let text = text.trimmingCharacters(in: .whitespaces).lowercased()
		if text == "0" || text == "auto" || text == "none" {
			value = 0
			unit = .points
			return
		}

		let units: [(String, Double, Unit)] = [
			("rem", 1, .em), ("em", 1, .em), ("ex", 0.5, .em), ("ch", 0.5, .em),
			("px", 1, .points), ("pt", 4 / 3, .points), ("pc", 16, .points), ("in", 96, .points), ("cm", 37.8, .points), ("mm", 3.78, .points),
			("%", 1, .percent),
		]
		for (suffix, factor, unit) in units where text.hasSuffix(suffix) {
			guard let number = Double(text.dropLast(suffix.count)) else { return nil }
			value = number * factor
			self.unit = unit
			return
		}
		return nil
	}

	/// The length in points, for text of a font size inside a block of a width.
	func points(fontSize: Double, width: Double) -> Double {
		switch unit {
		case .em: value * fontSize
		case .points: value
		case .percent: value / 100 * width
		}
	}
}
