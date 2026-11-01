import Foundation

/// The simple rules from a book's style sheets: `tag`, `.class`, and `tag.class` selectors.
/// Selectors with descendants, pseudo-classes, and the like are skipped rather than guessed at.
nonisolated struct StyleSheet: Sendable {
	private var rules: [String: CSSStyle] = [:]
	/// Styles for the first letter of elements, from `::first-letter` selectors.
	private var firstLetterRules: [String: CSSStyle] = [:]
	/// Styles for content generated before and after elements, from `::before` and `::after` selectors.
	private var beforeRules: [String: CSSStyle] = [:]
	private var afterRules: [String: CSSStyle] = [:]

	init() {}

	init(css: String) {
		let withoutComments = Self.removingComments(from: css)

		for block in withoutComments.split(separator: "}") {
			let parts = block.split(separator: "{", maxSplits: 1)
			guard parts.count == 2 else { continue }

			let style = CSSStyle(declarations: String(parts[1]))
			for selector in parts[0].split(separator: ",") {
				var selector = selector.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
				var pseudo = ""
				for suffix in ["first-letter", "before", "after"] {
					for prefix in ["::", ":"] where selector.hasSuffix(prefix + suffix) {
						selector.removeLast(prefix.count + suffix.count)
						pseudo = suffix
					}
				}

				guard Self.isSimpleSelector(selector) else { continue }
				switch pseudo {
				case "first-letter": firstLetterRules[selector, default: CSSStyle()].merge(style)
				case "before": beforeRules[selector, default: CSSStyle()].merge(style)
				case "after": afterRules[selector, default: CSSStyle()].merge(style)
				default: rules[selector, default: CSSStyle()].merge(style)
				}
			}
		}
	}

	/// Matches `tag`, `.class`, or `tag.class`. Written out by hand: regular expressions here were rebuilt for every
	/// selector, which made books with a style block in every chapter take seconds to open.
	private static func isSimpleSelector(_ selector: String) -> Bool {
		guard !selector.isEmpty else { return false }

		let parts = selector.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
		let isTag = parts[0].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
		guard parts.count == 2 else { return isTag }

		let isClass = !parts[1].isEmpty && parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
		return isTag && isClass
	}

	private static func removingComments(from css: String) -> String {
		var result = ""
		var rest = css[...]
		while let start = rest.range(of: "/*") {
			result += rest[..<start.lowerBound]
			guard let end = rest[start.upperBound...].range(of: "*/") else { return result }
			rest = rest[end.upperBound...]
		}
		return result + rest
	}

	mutating func merge(_ other: StyleSheet) {
		for (selector, style) in other.rules {
			rules[selector, default: CSSStyle()].merge(style)
		}
		for (selector, style) in other.firstLetterRules {
			firstLetterRules[selector, default: CSSStyle()].merge(style)
		}
		for (selector, style) in other.beforeRules {
			beforeRules[selector, default: CSSStyle()].merge(style)
		}
		for (selector, style) in other.afterRules {
			afterRules[selector, default: CSSStyle()].merge(style)
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

	/// The style of content generated before or after an element.
	func generatedStyle(forTag tag: String, classes: [String], after: Bool) -> CSSStyle {
		Self.style(in: after ? afterRules : beforeRules, forTag: tag, classes: classes)
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
