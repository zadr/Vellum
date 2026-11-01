import Foundation

/// An element of a chapter's document, kept as a tree so style selectors can look at parents and siblings.
nonisolated final class HTMLNode {
	enum Child {
		case element(HTMLNode)
		case text(String)
	}

	let name: String
	let attributes: [String: String]
	let id: String?
	let classes: [String]
	private(set) var children: [Child] = []
	private(set) weak var parent: HTMLNode?
	/// The element children of the parent, in order, and this element's place among them.
	private(set) var elementIndex = 0

	init(name: String, attributes: [String: String]) {
		self.name = name
		self.attributes = attributes
		id = attributes["id"]
		classes = attributes["class"]?.lowercased().split(whereSeparator: \.isWhitespace).map(String.init) ?? []
	}

	var elementChildren: [HTMLNode] {
		children.compactMap { if case .element(let node) = $0 { node } else { nil } }
	}

	var siblings: [HTMLNode] {
		parent?.elementChildren ?? [self]
	}

	var previousSibling: HTMLNode? {
		guard let parent, elementIndex > 0 else { return nil }
		return parent.elementChildren[elementIndex - 1]
	}

	func append(_ child: Child) {
		if case .element(let node) = child {
			node.parent = self
			node.elementIndex = elementChildren.count
		}
		// Adjacent text joins up, as the parser can deliver one run of text in pieces.
		if case .text(let text) = child, case .text(let previous)? = children.last {
			children[children.count - 1] = .text(previous + text)
		} else {
			children.append(child)
		}
	}

	/// Parses a chapter's markup into a tree, or returns `nil` if it isn't well-formed XML.
	static func parse(_ data: Data) -> HTMLNode? {
		let builder = Builder()
		let parser = XMLParser(data: data)
		parser.shouldProcessNamespaces = true
		parser.shouldResolveExternalEntities = false
		parser.delegate = builder
		return parser.parse() ? builder.root.elementChildren.first : nil
	}

	private final class Builder: NSObject, XMLParserDelegate {
		let root = HTMLNode(name: "#document", attributes: [:])
		private lazy var stack = [root]

		func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
			let node = HTMLNode(name: elementName.lowercased(), attributes: attributes)
			stack[stack.count - 1].append(.element(node))
			stack.append(node)
		}

		func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
			if stack.count > 1 {
				stack.removeLast()
			}
		}

		func parser(_ parser: XMLParser, foundCharacters string: String) {
			stack[stack.count - 1].append(.text(string))
		}

		func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
			if let text = String(data: CDATABlock, encoding: .utf8) {
				stack[stack.count - 1].append(.text(text))
			}
		}
	}
}
