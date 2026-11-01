import Foundation

/// The simple rules from a book's style sheets: `tag`, `.class`, and `tag.class` selectors.
/// Selectors with descendants, pseudo-classes, and the like are skipped rather than guessed at.
nonisolated struct StyleSheet: Sendable {
	private var rules: [String: CSSStyle] = [:]

	init() {}

	init(css: String) {
		let withoutComments = css.replacing(/\/\*[\s\S]*?\*\//, with: "")

		for block in withoutComments.split(separator: "}") {
			let parts = block.split(separator: "{", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let style = CSSStyle(declarations: String(parts[1]))
			for selector in parts[0].split(separator: ",") {
				let selector = selector.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
				guard selector.wholeMatch(of: /[a-z0-9]*(\.[a-z0-9_-]+)?/) != nil, !selector.isEmpty else { continue }
				rules[selector, default: CSSStyle()].merge(style)
			}
		}
	}

	mutating func merge(_ other: StyleSheet) {
		for (selector, style) in other.rules {
			rules[selector, default: CSSStyle()].merge(style)
		}
	}

	/// The style for an element, applying tag rules, then class rules, then tag-and-class rules.
	func style(forTag tag: String, classes: [String]) -> CSSStyle {
		var style = rules[tag] ?? CSSStyle()

		for name in classes {
			if let rule = rules["." + name] {
				style.merge(rule)
			}
		}
		for name in classes {
			if let rule = rules[tag + "." + name] {
				style.merge(rule)
			}
		}

		return style
	}
}
