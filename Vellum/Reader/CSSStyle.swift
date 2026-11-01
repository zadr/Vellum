import CoreText
import Foundation

/// The handful of CSS properties the reader honors. Anything else in a book's styles is ignored.
nonisolated struct CSSStyle: Sendable {
	var alignment: CTTextAlignment?
	var isItalic: Bool?
	var isBold: Bool?
	/// Relative to the parent element's text size.
	var fontScale: Double?
	var isHidden = false
	var floatsLeft: Bool?

	init() {}

	/// Parses declarations like `text-align: center; font-style: italic`.
	init(declarations: String) {
		for declaration in declarations.split(separator: ";") {
			let parts = declaration.split(separator: ":", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			let value = parts[1].replacing("!important", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

			switch property {
			case "text-align":
				alignment = switch value {
				case "center": .center
				case "right", "end": .right
				case "left", "start", "justify": .natural
				default: alignment
				}
			case "font-style":
				isItalic = value == "italic" || value == "oblique"
			case "font-weight":
				isBold = value == "bold" || value == "bolder" || (Int(value) ?? 400) >= 600
			case "font-size":
				fontScale = Self.fontScale(from: value) ?? fontScale
			case "float":
				floatsLeft = value == "left"
			case "display":
				isHidden = value == "none"
			default:
				break
			}
		}
	}

	/// Later styles win, as they would in a browser.
	mutating func merge(_ other: CSSStyle) {
		alignment = other.alignment ?? alignment
		isItalic = other.isItalic ?? isItalic
		isBold = other.isBold ?? isBold
		fontScale = other.fontScale ?? fontScale
		floatsLeft = other.floatsLeft ?? floatsLeft
		isHidden = isHidden || other.isHidden
	}

	/// How many lines a drop cap with this style spans, if the style makes one: a large letter floated to the left.
	var dropCapLines: Int? {
		guard floatsLeft == true, let fontScale, fontScale >= 1.8 else { return nil }
		// Designers size drop caps by the lines they span; about 1.5× the text size per line covers how books do it.
		return min(max(Int((fontScale / 1.5).rounded()), 2), 4)
	}

	private static func fontScale(from value: String) -> Double? {
		let keywords = ["xx-small": 0.6, "x-small": 0.75, "small": 0.89, "smaller": 0.85, "medium": 1, "large": 1.2, "larger": 1.2, "x-large": 1.5, "xx-large": 2]
		if let scale = keywords[value] {
			return scale
		}

		let units = [("em", 1.0), ("rem", 1.0), ("%", 0.01), ("px", 1 / 16.0), ("pt", 1 / 12.0)]
		for (unit, factor) in units where value.hasSuffix(unit) {
			guard let number = Double(value.dropLast(unit.count)) else { return nil }
			// Keep odd sizes from making text unreadable or a single word fill the page.
			return min(max(number * factor, 0.6), 2.5)
		}

		return nil
	}
}
