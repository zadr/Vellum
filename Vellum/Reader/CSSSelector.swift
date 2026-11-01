import Foundation

/// A CSS selector, matched against elements of a chapter's document tree. Supports type, universal, class, ID, and
/// attribute selectors; descendant, child, and sibling combinators; and the structural pseudo-classes and `:not()`.
/// Pseudo-classes that depend on interaction, like `:hover`, never match, as in a printed book.
nonisolated struct CSSSelector: Sendable {
	struct Compound: Sendable {
		enum AttributeTest: Sendable {
			case exists
			case equals(String)
			/// `~=`: one of the space-separated words.
			case containsWord(String)
			/// `|=`: equal, or followed by a hyphen.
			case language(String)
			case prefix(String)
			case suffix(String)
			case substring(String)
		}

		indirect enum Pseudo: Sendable {
			case firstChild
			case lastChild
			case onlyChild
			case firstOfType
			case lastOfType
			case onlyOfType
			case nthChild(Int, Int, ofType: Bool, fromEnd: Bool)
			case root
			case empty
			case not([Compound])
			/// A link: an `a` with an `href`.
			case link
			case never
		}

		var tag: String?
		var id: String?
		var classes: [String] = []
		var attributes: [(name: String, test: AttributeTest)] = []
		var pseudos: [Pseudo] = []

		func matches(_ node: HTMLNode) -> Bool {
			if let tag, tag != node.name { return false }
			if let id, id != node.id { return false }
			for name in classes where !node.classes.contains(name) { return false }

			for (name, test) in attributes {
				guard let value = node.attributes[name] ?? node.attributes.first(where: { $0.key.lowercased() == name })?.value else { return false }
				let matched = switch test {
				case .exists: true
				case .equals(let expected): value == expected
				case .containsWord(let word): value.split(whereSeparator: \.isWhitespace).contains { $0 == word }
				case .language(let language): value == language || value.hasPrefix(language + "-")
				case .prefix(let prefix): !prefix.isEmpty && value.hasPrefix(prefix)
				case .suffix(let suffix): !suffix.isEmpty && value.hasSuffix(suffix)
				case .substring(let part): !part.isEmpty && value.contains(part)
				}
				if !matched { return false }
			}

			for pseudo in pseudos where !Self.matches(pseudo, node) { return false }
			return true
		}

		private static func matches(_ pseudo: Pseudo, _ node: HTMLNode) -> Bool {
			let siblings = node.siblings
			let ofType = siblings.filter { $0.name == node.name }
			let index = node.elementIndex
			let typeIndex = ofType.firstIndex { $0 === node } ?? 0

			switch pseudo {
			case .firstChild: return index == 0
			case .lastChild: return index == siblings.count - 1
			case .onlyChild: return siblings.count == 1
			case .firstOfType: return typeIndex == 0
			case .lastOfType: return typeIndex == ofType.count - 1
			case .onlyOfType: return ofType.count == 1
			case .nthChild(let a, let b, let byType, let fromEnd):
				let count = byType ? ofType.count : siblings.count
				let position = (byType ? typeIndex : index) + 1
				let n = fromEnd ? count - position + 1 : position
				// Whether n = a*k + b for some k ≥ 0.
				if a == 0 { return n == b }
				return (n - b) % a == 0 && (n - b) / a >= 0
			case .root: return node.parent?.name == "#document" || node.parent == nil
			case .empty: return node.children.allSatisfy { if case .text(let text) = $0 { text.isEmpty } else { false } }
			case .not(let compounds): return !compounds.contains { $0.matches(node) }
			case .link: return node.name == "a" && node.attributes["href"] != nil
			case .never: return false
			}
		}

		/// Specificity as (IDs, classes and attributes and pseudo-classes, types).
		var specificity: (Int, Int, Int) {
			var result = (id == nil ? 0 : 1, classes.count + attributes.count, tag == nil ? 0 : 1)
			for pseudo in pseudos {
				if case .not(let inner) = pseudo, let most = inner.map(\.specificity).max(by: { $0 < $1 }) {
					result = (result.0 + most.0, result.1 + most.1, result.2 + most.2)
				} else {
					result.1 += 1
				}
			}
			return result
		}
	}

	enum Combinator: Sendable {
		case descendant
		case child
		case adjacentSibling
		case generalSibling
	}

	/// Compounds from right to left, each with the combinator joining it to the next one leftwards.
	let parts: [(compound: Compound, combinator: Combinator?)]
	let specificity: (Int, Int, Int)

	/// The rightmost compound, which an element has to match before the rest is checked.
	var subject: Compound {
		parts[0].compound
	}

	func matches(_ node: HTMLNode) -> Bool {
		Self.matches(parts[...], node)
	}

	private static func matches(_ parts: ArraySlice<(compound: Compound, combinator: Combinator?)>, _ node: HTMLNode) -> Bool {
		guard let first = parts.first, first.compound.matches(node) else { return false }
		guard let combinator = first.combinator else { return true }

		let rest = parts.dropFirst()
		switch combinator {
		case .child:
			return node.parent.map { matches(rest, $0) } ?? false
		case .descendant:
			var ancestor = node.parent
			while let current = ancestor {
				if matches(rest, current) { return true }
				ancestor = current.parent
			}
			return false
		case .adjacentSibling:
			return node.previousSibling.map { matches(rest, $0) } ?? false
		case .generalSibling:
			var sibling = node.previousSibling
			while let current = sibling {
				if matches(rest, current) { return true }
				sibling = current.previousSibling
			}
			return false
		}
	}

	// MARK: Parsing

	/// Parses a selector, returning it with its pseudo-element, if any. Returns `nil` for selectors it can't read,
	/// so a rule it doesn't understand is skipped instead of applied too widely.
	static func parse(_ text: String) -> (selector: CSSSelector, pseudoElement: String?)? {
		var scanner = Scanner(text: text.trimmingCharacters(in: .whitespacesAndNewlines))
		var compounds = [Compound]()
		var combinators = [Combinator]()
		var pseudoElement: String?

		while !scanner.isAtEnd {
			guard let (compound, element) = scanner.compound() else { return nil }
			compounds.append(compound)
			if let element {
				pseudoElement = element
				scanner.skipWhitespace()
				guard scanner.isAtEnd else { return nil }
				break
			}

			let hadSpace = scanner.skipWhitespace()
			if scanner.isAtEnd { break }
			switch scanner.peek {
			case ">": scanner.advance(); combinators.append(.child)
			case "+": scanner.advance(); combinators.append(.adjacentSibling)
			case "~": scanner.advance(); combinators.append(.generalSibling)
			default:
				guard hadSpace else { return nil }
				combinators.append(.descendant)
			}
			scanner.skipWhitespace()
		}

		guard !compounds.isEmpty, combinators.count == compounds.count - 1 else { return nil }

		var parts = [(compound: Compound, combinator: Combinator?)]()
		for index in compounds.indices.reversed() {
			parts.append((compounds[index], index > 0 ? combinators[index - 1] : nil))
		}

		var specificity = (0, 0, pseudoElement == nil ? 0 : 1)
		for compound in compounds {
			let s = compound.specificity
			specificity = (specificity.0 + s.0, specificity.1 + s.1, specificity.2 + s.2)
		}
		return (CSSSelector(parts: parts, specificity: specificity), pseudoElement)
	}

	private struct Scanner {
		let characters: [Character]
		var index = 0

		init(text: String) {
			characters = Array(text)
		}

		var isAtEnd: Bool { index >= characters.count }
		var peek: Character? { isAtEnd ? nil : characters[index] }

		mutating func advance() {
			index += 1
		}

		@discardableResult
		mutating func skipWhitespace() -> Bool {
			let start = index
			while let character = peek, character.isWhitespace { advance() }
			return index > start
		}

		mutating func identifier() -> String? {
			let start = index
			while let character = peek, character.isLetter || character.isNumber || character == "-" || character == "_" || character == "\\" {
				if character == "\\" { advance() }
				advance()
			}
			guard index > start else { return nil }
			return String(characters[start..<index]).replacing("\\", with: "")
		}

		/// A compound selector, and the pseudo-element that ends it, if there is one.
		mutating func compound() -> (Compound, String?)? {
			var compound = Compound()
			var parsedAnything = false

			if peek == "*" {
				advance()
				parsedAnything = true
			} else if let tag = identifier() {
				compound.tag = tag.lowercased()
				parsedAnything = true
			}

			while let character = peek {
				switch character {
				case ".":
					advance()
					guard let name = identifier() else { return nil }
					compound.classes.append(name.lowercased())
				case "#":
					advance()
					guard let name = identifier() else { return nil }
					compound.id = name
				case "[":
					advance()
					guard let test = attribute() else { return nil }
					compound.attributes.append(test)
				case ":":
					advance()
					if peek == ":" {
						advance()
						guard let name = identifier()?.lowercased() else { return nil }
						return (compound, name)
					}
					guard let name = identifier()?.lowercased() else { return nil }
					if ["first-letter", "first-line", "before", "after"].contains(name) {
						return (compound, name)
					}
					guard let pseudo = pseudoClass(name) else { return nil }
					compound.pseudos.append(pseudo)
				default:
					return parsedAnything ? (compound, nil) : nil
				}
				parsedAnything = true
			}
			return parsedAnything ? (compound, nil) : nil
		}

		mutating func attribute() -> (name: String, test: Compound.AttributeTest)? {
			skipWhitespace()
			guard var name = identifier() else { return nil }
			// Namespaced attributes, like epub|type, are matched by their local name.
			if peek == "|", index + 1 < characters.count, characters[index + 1] != "=" {
				advance()
				name = identifier() ?? name
			}
			name = name.lowercased()
			skipWhitespace()

			if peek == "]" {
				advance()
				return (name, .exists)
			}

			var op = ""
			while let character = peek, "~|^$*=".contains(character) {
				op.append(character)
				advance()
			}
			skipWhitespace()

			var value = ""
			if let quote = peek, quote == "\"" || quote == "'" {
				advance()
				while let character = peek, character != quote {
					value.append(character)
					advance()
				}
				advance()
			} else {
				value = identifier() ?? ""
			}
			skipWhitespace()
			// Case-insensitivity flags aren't needed for books' selectors.
			if peek == "i" || peek == "s" { advance(); skipWhitespace() }
			guard peek == "]" else { return nil }
			advance()

			switch op {
			case "=": return (name, .equals(value))
			case "~=": return (name, .containsWord(value))
			case "|=": return (name, .language(value))
			case "^=": return (name, .prefix(value))
			case "$=": return (name, .suffix(value))
			case "*=": return (name, .substring(value))
			default: return nil
			}
		}

		mutating func pseudoClass(_ name: String) -> Compound.Pseudo? {
			switch name {
			case "first-child": return .firstChild
			case "last-child": return .lastChild
			case "only-child": return .onlyChild
			case "first-of-type": return .firstOfType
			case "last-of-type": return .lastOfType
			case "only-of-type": return .onlyOfType
			case "root": return .root
			case "empty": return .empty
			case "link", "any-link": return .link
			case "hover", "active", "focus", "visited", "focus-within", "focus-visible", "target", "checked", "disabled", "enabled":
				return .never
			case "nth-child", "nth-of-type", "nth-last-child", "nth-last-of-type":
				guard let (a, b) = nthArguments() else { return nil }
				return .nthChild(a, b, ofType: name.hasSuffix("of-type"), fromEnd: name.contains("last"))
			case "not":
				guard peek == "(" else { return nil }
				advance()
				var compounds = [Compound]()
				repeat {
					skipWhitespace()
					guard let (compound, element) = compound(), element == nil else { return nil }
					compounds.append(compound)
					skipWhitespace()
				} while peek == "," && { advance(); return true }()
				guard peek == ")" else { return nil }
				advance()
				return .not(compounds)
			default:
				return nil
			}
		}

		/// The `an+b` inside `:nth-child(…)`, including `odd` and `even`.
		mutating func nthArguments() -> (Int, Int)? {
			guard peek == "(" else { return nil }
			advance()
			var text = ""
			while let character = peek, character != ")" {
				text.append(character)
				advance()
			}
			guard peek == ")" else { return nil }
			advance()

			let expression = text.lowercased().filter { !$0.isWhitespace }
			switch expression {
			case "odd": return (2, 1)
			case "even": return (2, 0)
			default: break
			}

			guard let n = expression.firstIndex(of: "n") else { return Int(expression).map { (0, $0) } }
			let aText = String(expression[..<n])
			let a = aText.isEmpty || aText == "+" ? 1 : aText == "-" ? -1 : Int(aText)
			let bText = String(expression[expression.index(after: n)...])
			let b = bText.isEmpty ? 0 : Int(bText)
			guard let a, let b else { return nil }
			return (a, b)
		}
	}
}

