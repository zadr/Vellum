import Foundation

/// The simple rules from a book's style sheets: `tag`, `.class`, and `tag.class` selectors.
/// Selectors with descendants, pseudo-classes, and the like are skipped rather than guessed at.
nonisolated struct StyleSheet: Sendable {
	private var rules: [String: CSSStyle] = [:]
	/// Styles for the first letter of elements, from `::first-letter` selectors.
	private var firstLetterRules: [String: CSSStyle] = [:]

	init() {}

	init(css: String) {
		let withoutComments = css.replacing(/\/\*[\s\S]*?\*\//, with: "")

		for block in withoutComments.split(separator: "}") {
			let parts = block.split(separator: "{", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let style = CSSStyle(declarations: String(parts[1]))
			for selector in parts[0].split(separator: ",") {
				var selector = selector.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
				var isFirstLetter = false
				if let range = selector.firstRange(of: /::?first-letter$/) {
					selector.removeSubrange(range)
					isFirstLetter = true
				}

				guard selector.wholeMatch(of: /[a-z0-9]*(\.[a-z0-9_-]+)?/) != nil, !selector.isEmpty else { continue }
				if isFirstLetter {
					firstLetterRules[selector, default: CSSStyle()].merge(style)
				} else {
					rules[selector, default: CSSStyle()].merge(style)
				}
			}
		}
	}

	mutating func merge(_ other: StyleSheet) {
		for (selector, style) in other.rules {
			rules[selector, default: CSSStyle()].merge(style)
		}
		for (selector, style) in other.firstLetterRules {
			firstLetterRules[selector, default: CSSStyle()].merge(style)
		}
	}

	/// The style for an element, applying tag rules, then class rules, then tag-and-class rules.
	func style(forTag tag: String, classes: [String]) -> CSSStyle {
		Self.style(in: rules, forTag: tag, classes: classes)
	}

	/// The style for an element's first letter.
	func firstLetterStyle(forTag tag: String, classes: [String]) -> CSSStyle {
		Self.style(in: firstLetterRules, forTag: tag, classes: classes)
	}

	private static func style(in rules: [String: CSSStyle], forTag tag: String, classes: [String]) -> CSSStyle {
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
