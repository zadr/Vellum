import CoreGraphics
import Foundation

/// Reads CSS colors: hex, rgb() and rgba(), hsl() and hsla(), and named colors.
nonisolated enum CSSColor {
	/// The color a value describes. `nil` for values that don't set one, like `inherit` or `transparent`.
	static func parse(_ text: String) -> CGColor? {
		let value = text.trimmingCharacters(in: .whitespaces).lowercased()

		if value.hasPrefix("#") {
			return hex(String(value.dropFirst()))
		}
		if value.hasPrefix("rgb") {
			let numbers = arguments(value)
			guard numbers.count >= 3 else { return nil }
			let channels = numbers.prefix(3).map { $0.hasSuffix("%") ? (Double($0.dropLast()) ?? 0) / 100 : (Double($0) ?? 0) / 255 }
			return CGColor(srgbRed: channels[0], green: channels[1], blue: channels[2], alpha: alpha(numbers))
		}
		if value.hasPrefix("hsl") {
			let numbers = arguments(value)
			guard numbers.count >= 3 else { return nil }
			let hue = (Double(numbers[0].replacing("deg", with: "")) ?? 0) / 360
			let saturation = (Double(numbers[1].replacing("%", with: "")) ?? 0) / 100
			let lightness = (Double(numbers[2].replacing("%", with: "")) ?? 0) / 100
			let (r, g, b) = hslToRGB(hue, saturation, lightness)
			return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha(numbers))
		}
		return named[value].flatMap { hex($0) }
	}

	private static func arguments(_ value: String) -> [String] {
		guard let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")") else { return [] }
		return value[value.index(after: open)..<close]
			.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
			.map(String.init)
	}

	private static func alpha(_ numbers: [String]) -> Double {
		guard numbers.count >= 4 else { return 1 }
		let text = numbers[3]
		return text.hasSuffix("%") ? (Double(text.dropLast()) ?? 100) / 100 : Double(text) ?? 1
	}

	private static func hex(_ digits: String) -> CGColor? {
		var digits = digits
		if digits.count == 3 || digits.count == 4 {
			digits = digits.map { "\($0)\($0)" }.joined()
		}
		guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }

		let hasAlpha = digits.count == 8
		let shift: UInt64 = hasAlpha ? 8 : 0
		return CGColor(
			srgbRed: Double((value >> (16 + shift)) & 0xFF) / 255,
			green: Double((value >> (8 + shift)) & 0xFF) / 255,
			blue: Double((value >> shift) & 0xFF) / 255,
			alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
		)
	}

	private static func hslToRGB(_ h: Double, _ s: Double, _ l: Double) -> (Double, Double, Double) {
		guard s > 0 else { return (l, l, l) }
		let q = l < 0.5 ? l * (1 + s) : l + s - l * s
		let p = 2 * l - q
		func channel(_ t: Double) -> Double {
			var t = t
			if t < 0 { t += 1 }
			if t > 1 { t -= 1 }
			if t < 1 / 6 { return p + (q - p) * 6 * t }
			if t < 1 / 2 { return q }
			if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
			return p
		}
		return (channel(h + 1 / 3), channel(h), channel(h - 1 / 3))
	}

	/// The CSS named colors, as hex.
	private static let named: [String: String] = [
		"black": "000000", "white": "ffffff", "red": "ff0000", "green": "008000", "blue": "0000ff", "yellow": "ffff00",
		"gray": "808080", "grey": "808080", "silver": "c0c0c0", "maroon": "800000", "purple": "800080", "fuchsia": "ff00ff",
		"lime": "00ff00", "olive": "808000", "navy": "000080", "teal": "008080", "aqua": "00ffff", "orange": "ffa500",
		"darkgray": "a9a9a9", "darkgrey": "a9a9a9", "dimgray": "696969", "dimgrey": "696969", "lightgray": "d3d3d3",
		"lightgrey": "d3d3d3", "gainsboro": "dcdcdc", "whitesmoke": "f5f5f5", "darkred": "8b0000", "brown": "a52a2a",
		"firebrick": "b22222", "crimson": "dc143c", "indianred": "cd5c5c", "darkblue": "00008b", "midnightblue": "191970",
		"royalblue": "4169e1", "steelblue": "4682b4", "dodgerblue": "1e90ff", "skyblue": "87ceeb", "lightblue": "add8e6",
		"darkgreen": "006400", "forestgreen": "228b22", "seagreen": "2e8b57", "darkolivegreen": "556b2f", "gold": "ffd700",
		"goldenrod": "daa520", "darkgoldenrod": "b8860b", "tan": "d2b48c", "beige": "f5f5dc", "ivory": "fffff0",
		"linen": "faf0e6", "wheat": "f5deb3", "khaki": "f0e68c", "pink": "ffc0cb", "hotpink": "ff69b4", "salmon": "fa8072",
		"coral": "ff7f50", "tomato": "ff6347", "orangered": "ff4500", "chocolate": "d2691e", "sienna": "a0522d",
		"saddlebrown": "8b4513", "indigo": "4b0082", "violet": "ee82ee", "orchid": "da70d6", "plum": "dda0dd",
		"lavender": "e6e6fa", "slategray": "708090", "slategrey": "708090", "darkslategray": "2f4f4f", "cyan": "00ffff",
		"magenta": "ff00ff", "turquoise": "40e0d0", "cornflowerblue": "6495ed", "aliceblue": "f0f8ff", "snow": "fffafa",
		"seashell": "fff5ee", "oldlace": "fdf5e6", "antiquewhite": "faebd7", "mintcream": "f5fffa", "honeydew": "f0fff0",
		"rebeccapurple": "663399", "darkorange": "ff8c00", "lightyellow": "ffffe0", "lemonchiffon": "fffacd",
	]
}
