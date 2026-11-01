import CoreGraphics
import CoreText
import Foundation

/// The CSS declarations that apply to an element, with accessors for the properties the reader honors.
/// Anything else in a book's styles is kept but ignored.
nonisolated struct CSSStyle: Sendable {
	/// Declared values by property name, with shorthands like `margin` expanded into their parts.
	private(set) var properties: [String: String] = [:]

	init() {}

	/// Parses declarations like `text-align: center; font-style: italic`, including any marked `!important`.
	init(declarations: String) {
		let (normal, important) = Self.parse(declarations)
		self = normal
		merge(important)
	}

	/// Declarations split by importance, as the cascade applies `!important` ones after all others.
	static func parse(_ declarations: String) -> (normal: CSSStyle, important: CSSStyle) {
		var normal = CSSStyle(), important = CSSStyle()

		for declaration in declarations.split(separator: ";") {
			let parts = declaration.split(separator: ":", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
			if let range = value.range(of: "!important", options: .caseInsensitive) {
				value.removeSubrange(range)
				important.set(property, to: value.trimmingCharacters(in: .whitespaces))
			} else {
				normal.set(property, to: value)
			}
		}
		return (normal, important)
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
		// Pixel and point sizes are taken relative to the 16-pixel default, so they scale with the reader's text size.
		let scale = length.points(fontSize: 1, width: 1) / (length.unit == .points ? 16 : 1)
		return scale > 0 ? scale : nil
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

	var isUnderlined: Bool? {
		decoration.map { $0.contains("underline") }
	}

	var isStruckThrough: Bool? {
		decoration.map { $0.contains("line-through") }
	}

	private var decoration: String? {
		value("text-decoration-line") ?? value("text-decoration")
	}

	/// The width of a border on one side, in points, if the book draws one there.
	func borderWidth(_ side: String) -> Double? {
		let value = value("border-\(side)") ?? value("border")
		guard let value, !value.contains("none"), !value.contains("hidden") else {
			return length("border-\(side)-width").map { $0.points(fontSize: 16, width: 0) }.flatMap { $0 > 0 ? $0 : nil }
		}

		let parts = value.split(separator: " ").map(String.init)
		guard parts.contains(where: { ["solid", "double", "dotted", "dashed", "groove", "ridge", "inset", "outset"].contains($0) }) || parts.contains(where: { CSSLength($0) != nil }) else { return nil }

		let keywords = ["thin": 1.0, "medium": 3.0, "thick": 5.0]
		let width = parts.lazy.compactMap { keywords[$0] ?? CSSLength($0)?.points(fontSize: 16, width: 0) }.first ?? 3
		return width > 0 ? min(width, 8) : nil
	}

	/// The text a `::before` or `::after` rule adds: quoted strings, with CSS escapes, and quote marks.
	/// `quoteDepth` counts open quotes, so nested quotes alternate between double and single marks.
	func generatedContent(quoteDepth: inout Int) -> String? {
		guard let content = properties["content"]?.trimmingCharacters(in: .whitespaces), content != "none", content != "normal" else { return nil }

		var text = ""
		var rest = content[...]
		while let first = rest.first {
			if first == "\"" || first == "'" {
				rest = rest.dropFirst()
				var literal = ""
				while let character = rest.first, character != first {
					rest = rest.dropFirst()
					if character == "\\" {
						let hex = rest.prefix { $0.isHexDigit }.prefix(6)
						if !hex.isEmpty, let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) {
							literal.unicodeScalars.append(scalar)
							rest = rest.dropFirst(hex.count)
							if rest.first == " " { rest = rest.dropFirst() }
						} else if let escaped = rest.first {
							literal.append(escaped)
							rest = rest.dropFirst()
						}
					} else {
						literal.append(character)
					}
				}
				rest = rest.dropFirst()
				text += literal
			} else if rest.hasPrefix("open-quote") {
				text += quoteDepth.isMultiple(of: 2) ? "“" : "‘"
				quoteDepth += 1
				rest = rest.dropFirst("open-quote".count)
			} else if rest.hasPrefix("close-quote") {
				quoteDepth = max(quoteDepth - 1, 0)
				text += quoteDepth.isMultiple(of: 2) ? "”" : "’"
				rest = rest.dropFirst("close-quote".count)
			} else {
				// Counters, attributes, and images aren't supported; skip to the next part.
				rest = rest.drop { $0 != " " }.dropFirst()
			}
		}
		return text.isEmpty ? nil : text
	}

	/// Whether the element must start on a new page.
	var breaksPageBefore: Bool {
		["always", "page", "left", "right"].contains(value("page-break-before") ?? value("break-before") ?? "")
	}

	/// Whether whatever follows the element must start on a new page.
	var breaksPageAfter: Bool {
		["always", "page", "left", "right"].contains(value("page-break-after") ?? value("break-after") ?? "")
	}

	var widows: Int? {
		value("widows").flatMap(Int.init)
	}

	var orphans: Int? {
		value("orphans").flatMap(Int.init)
	}

	/// Whether the element should stay on the same page as whatever follows it, as headings do.
	var avoidsBreakAfter: Bool {
		(value("page-break-after") ?? value("break-after")) == "avoid"
	}

	/// The text color, if the book sets one.
	var color: CGColor? {
		(value("-webkit-text-fill-color") ?? value("color")).flatMap(CSSColor.parse)
	}

	/// The background color, from `background-color` or the color in a `background` shorthand.
	var backgroundColor: CGColor? {
		if let value = value("background-color") {
			return CSSColor.parse(value)
		}
		guard let shorthand = value("background") else { return nil }
		// The shorthand mixes colors with images and positions; take the first part that reads as a color.
		var parts = [String]()
		var current = ""
		var depth = 0
		for character in shorthand {
			if character == "(" { depth += 1 }
			if character == ")" { depth -= 1 }
			if character == " ", depth == 0 {
				parts.append(current)
				current = ""
			} else {
				current.append(character)
			}
		}
		parts.append(current)
		return parts.lazy.compactMap(CSSColor.parse).first
	}

	var isHidden: Bool {
		value("display") == "none"
	}

	var floatsLeft: Bool? {
		value("float").map { $0 == "left" }
	}
}
