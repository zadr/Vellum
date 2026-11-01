import CoreText
import Foundation

/// The CSS declarations that apply to an element, with accessors for the properties the reader honors.
/// Anything else in a book's styles is kept but ignored.
nonisolated struct CSSStyle: Sendable {
	/// Declared values by property name, with shorthands like `margin` expanded into their parts.
	private(set) var properties: [String: String] = [:]

	init() {}

	/// Parses declarations like `text-align: center; font-style: italic`.
	init(declarations: String) {
		for declaration in declarations.split(separator: ";") {
			let parts = declaration.split(separator: ":", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			let value = parts[1].replacing("!important", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
			set(property, to: value)
		}
	}

	/// Later styles win, as they would in a browser.
	mutating func merge(_ other: CSSStyle) {
		properties.merge(other.properties) { _, new in new }
	}

	private mutating func set(_ property: String, to value: String) {
		switch property {
		case "margin", "padding":
			// One to four values: top, right, bottom, left, with missing ones mirrored.
			let values = value.split(separator: " ").map(String.init)
			guard !values.isEmpty, values.count <= 4 else { return }
			let top = values[0], right = values.count > 1 ? values[1] : top
			let bottom = values.count > 2 ? values[2] : top, left = values.count > 3 ? values[3] : right
			for (side, value) in [("top", top), ("right", right), ("bottom", bottom), ("left", left)] {
				properties["\(property)-\(side)"] = value
			}
		default:
			properties[property] = value
		}
	}

	private func value(_ property: String) -> String? {
		properties[property]?.lowercased()
	}

	/// A length-valued property, if it's set to a length.
	func length(_ property: String) -> CSSLength? {
		value(property).flatMap(CSSLength.init)
	}

	// MARK: Text

	var alignment: CTTextAlignment? {
		switch value("text-align") {
		case "center": .center
		case "right", "end": .right
		case "justify": .justified
		case "left", "start": .natural
		default: nil
		}
	}

	var isItalic: Bool? {
		value("font-style").map { $0 == "italic" || $0 == "oblique" }
	}

	var isBold: Bool? {
		value("font-weight").map { $0 == "bold" || $0 == "bolder" || (Int($0) ?? 400) >= 600 }
	}

	/// Relative to the parent element's text size.
	var fontScale: Double? {
		guard let value = value("font-size") else { return nil }

		let keywords = ["xx-small": 0.6, "x-small": 0.75, "small": 0.89, "smaller": 0.85, "medium": 1, "large": 1.2, "larger": 1.2, "x-large": 1.5, "xx-large": 2]
		if let scale = keywords[value] {
			return scale
		}

		guard let length = CSSLength(value) else { return nil }
		// Pixel and point sizes are taken relative to the 16-pixel default. Odd sizes are kept from making text
		// unreadable or a single word fill the page.
		let scale = length.points(fontSize: 1, width: 1) / (length.unit == .points ? 16 : 1)
		return min(max(scale, 0.6), 2.5)
	}

	enum SmallCaps: Sendable {
		/// Lowercase letters become small capitals.
		case lowercase
		/// Every letter becomes a small capital.
		case all
	}

	/// `nil` when not set; `.some(nil)` when set to normal.
	var smallCaps: SmallCaps?? {
		guard let value = value("font-variant-caps") ?? value("font-variant") else { return nil }
		if value.contains("all-small-caps") { return .some(.all) }
		if value.contains("small-caps") { return .some(.lowercase) }
		return .some(nil)
	}

	enum TextTransform: Sendable {
		case none
		case uppercase
		case lowercase
		case capitalize
	}

	var textTransform: TextTransform? {
		switch value("text-transform") {
		case "uppercase": .uppercase
		case "lowercase": .lowercase
		case "capitalize": .capitalize
		case "none": TextTransform.none
		default: nil
		}
	}

	/// Extra space between letters, in ems. `nil` when not set; zero when set to normal.
	var letterSpacing: Double? {
		guard let value = value("letter-spacing") else { return nil }
		if value == "normal" { return 0 }
		guard let length = CSSLength(value), length.unit != .percent else { return nil }
		// Points are taken relative to the 16-pixel default, so the spacing scales with the text.
		return length.unit == .em ? length.value : length.value / 16
	}

	var isHidden: Bool {
		value("display") == "none"
	}

	var floatsLeft: Bool? {
		value("float").map { $0 == "left" }
	}

	/// How many lines a drop cap with this style spans, if the style makes one: a large letter floated to the left.
	var dropCapLines: Int? {
		guard floatsLeft == true, let fontScale, fontScale >= 1.8 else { return nil }
		// Designers size drop caps by the lines they span; about 1.5× the text size per line covers how books do it.
		return min(max(Int((fontScale / 1.5).rounded()), 2), 4)
	}
}
