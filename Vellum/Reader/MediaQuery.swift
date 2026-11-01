import CoreGraphics
import Foundation

/// Decides whether an `@media` block applies to the reader: a screen the size of the page.
/// Rules for print or for Kindle devices (`amzn-kf8`, `amzn-mobi`, and the like) don't apply.
nonisolated enum MediaQuery {
	/// Whether a media query list, the text after `@media`, matches a viewport of this size in CSS pixels.
	static func matches(_ list: String, viewport: CGSize) -> Bool {
		list.lowercased()
			.split(separator: ",")
			.contains { matchesQuery(String($0).trimmingCharacters(in: .whitespaces), viewport: viewport) }
	}

	private static func matchesQuery(_ query: String, viewport: CGSize) -> Bool {
		var query = query
		var negated = false
		if query.hasPrefix("not ") {
			negated = true
			query.removeFirst(4)
		} else if query.hasPrefix("only ") {
			query.removeFirst(5)
		}

		var matched = true
		for part in query.components(separatedBy: " and ") {
			let part = part.trimmingCharacters(in: .whitespaces)
			if part.hasPrefix("(") {
				matched = matched && matchesFeature(part.trimmingCharacters(in: CharacterSet(charactersIn: "() ")), viewport: viewport)
			} else if !part.isEmpty {
				matched = matched && (part == "all" || part == "screen")
			}
		}
		return negated ? !matched : matched
	}

	private static func matchesFeature(_ feature: String, viewport: CGSize) -> Bool {
		let parts = feature.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
		guard parts.count == 2 else {
			// A bare feature like (color) asks whether the screen has it; a phone screen does.
			return true
		}

		let (name, value) = (parts[0], parts[1])
		switch name {
		case "orientation":
			return value == (viewport.height >= viewport.width ? "portrait" : "landscape")
		case "min-aspect-ratio", "max-aspect-ratio", "aspect-ratio":
			let ratio = value.split(separator: "/").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
			guard ratio.count == 2, ratio[1] > 0 else { return true }
			let actual = viewport.width / viewport.height, wanted = ratio[0] / ratio[1]
			return name.hasPrefix("min") ? actual >= wanted : name.hasPrefix("max") ? actual <= wanted : abs(actual - wanted) < 0.01
		default:
			break
		}

		// Width and height in media queries are measured with ems of the 16-pixel default.
		guard let length = CSSLength(value) else { return true }
		let pixels = length.points(fontSize: 16, width: viewport.width)
		let dimension = name.contains("width") ? viewport.width : viewport.height

		if name.hasPrefix("min-") { return dimension >= pixels }
		if name.hasPrefix("max-") { return dimension <= pixels }
		if name.hasSuffix("width") || name.hasSuffix("height") { return dimension == pixels }
		return true
	}
}
