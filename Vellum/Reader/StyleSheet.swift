import Foundation

/// The rules from a book's style sheets, applied with the CSS cascade: matching rules in order of specificity,
/// then source order, with `!important` declarations last.
nonisolated struct StyleSheet: Sendable {
	private struct Rule: Sendable {
		let selector: CSSSelector
		let pseudoElement: String?
		let style: CSSStyle
		let isImportant: Bool
		let order: Int
	}

	private var rules: [Rule] = []
	/// Rules by the ID, first class, or type their selector's subject requires, or "*" for any element,
	/// so only rules that could match an element are checked.
	private var index: [String: [Int]] = [:]

	init() {}

	init(css: String) {
		let withoutComments = Self.removingComments(from: css)

		for block in Self.ruleBlocks(in: withoutComments) {
			let (normal, important) = CSSStyle.parse(block.declarations)
			for selectorText in block.selector.split(separator: ",") {
				guard let (selector, pseudoElement) = CSSSelector.parse(String(selectorText)) else { continue }
				if !normal.properties.isEmpty {
					add(Rule(selector: selector, pseudoElement: pseudoElement, style: normal, isImportant: false, order: rules.count))
				}
				if !important.properties.isEmpty {
					add(Rule(selector: selector, pseudoElement: pseudoElement, style: important, isImportant: true, order: rules.count))
				}
			}
		}
	}

	private mutating func add(_ rule: Rule) {
		let subject = rule.selector.subject
		let key = subject.id.map { "#" + $0 } ?? subject.classes.first.map { "." + $0 } ?? subject.tag ?? "*"
		index[key, default: []].append(rules.count)
		rules.append(rule)
	}

	mutating func merge(_ other: StyleSheet) {
		let offset = rules.count
		for rule in other.rules {
			add(Rule(selector: rule.selector, pseudoElement: rule.pseudoElement, style: rule.style, isImportant: rule.isImportant, order: offset + rule.order))
		}
	}

	/// The style of an element, or of one of its pseudo-elements like `first-letter`, `before`, or `after`.
	func style(for node: HTMLNode, pseudoElement: String? = nil) -> CSSStyle {
		var candidates = Set(index["*"] ?? [])
		candidates.formUnion(index[node.name] ?? [])
		if let id = node.id {
			candidates.formUnion(index["#" + id] ?? [])
		}
		for name in node.classes {
			candidates.formUnion(index["." + name] ?? [])
		}

		let matched = candidates
			.map { rules[$0] }
			.filter { $0.pseudoElement == pseudoElement && $0.selector.matches(node) }
			.sorted { lhs, rhs in
				if lhs.isImportant != rhs.isImportant { return !lhs.isImportant }
				if lhs.selector.specificity != rhs.selector.specificity { return lhs.selector.specificity < rhs.selector.specificity }
				return lhs.order < rhs.order
			}

		var style = CSSStyle()
		for rule in matched {
			style.merge(rule.style)
		}
		return style
	}

	/// The `selector { declarations }` blocks of a style sheet. At-rules like `@media` are entered, so their rules
	/// apply; `@font-face` and `@page` blocks, which describe fonts and printing, are skipped.
	private static func ruleBlocks(in css: String) -> [(selector: String, declarations: String)] {
		enum Context {
			case group
			case rule(String)
			case skipped
		}

		var blocks = [(String, String)]()
		var contexts = [Context]()
		var buffer = ""

		for character in css {
			let isSkipping = contexts.contains { if case .skipped = $0 { true } else { false } }

			switch character {
			case "{":
				let prelude = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
				if isSkipping || !prelude.hasPrefix("@") {
					contexts.append(isSkipping ? .skipped : .rule(prelude))
				} else {
					contexts.append(prelude.hasPrefix("@media") || prelude.hasPrefix("@supports") ? .group : .skipped)
				}
				buffer = ""
			case "}":
				if case .rule(let selector)? = contexts.popLast(), !isSkipping {
					blocks.append((selector, buffer))
				}
				buffer = ""
			case ";":
				// Outside a rule, a semicolon ends a statement at-rule like @import or @charset.
				if case .rule = contexts.last {
					buffer.append(character)
				} else {
					buffer = ""
				}
			default:
				buffer.append(character)
			}
		}
		return blocks
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
}
