import CoreText
import Foundation
import ImageIO

/// Turns a chapter's XHTML into text Core Text can lay out, keeping the structure a reader notices:
/// paragraphs, headings, emphasis, quotes, lists, line breaks, and images.
nonisolated final class ChapterConverter {
	struct Output {
		let text: NSAttributedString
		/// Where each element with an `id` starts, so links and the table of contents can find it.
		let anchors: [String: Int]
	}

	static let imageAttribute = NSAttributedString.Key("VellumImage")
	/// Marks the letters of a drop cap at the start of a paragraph. The value is its `DropCapStyle`.
	static let dropCapAttribute = NSAttributedString.Key("VellumDropCap")
	/// The `ParagraphFormat` for the paragraph the text belongs to.
	static let formatAttribute = NSAttributedString.Key("VellumParagraphFormat")
	/// Where a link goes: a file in the book, with any fragment, or a web address.
	static let linkAttribute = NSAttributedString.Key("VellumLink")

	private enum Block: Hashable {
		case paragraph
		case heading(Int)
		case quote
		case listItem
		case preformatted
		case image
	}

	private struct Element {
		let name: String
		var block: Block?
		var isBold: Bool?
		var isItalic: Bool?
		var fontScale: Double?
		var alignment: CTTextAlignment?
		var superscript: Int?
		var isPreformatted = false
		var isOrderedList = false
		var listCount = 0
		var dropCap: DropCapStyle?
		var smallCaps: CSSStyle.SmallCaps??
		var textTransform: CSSStyle.TextTransform?
		var letterSpacing: Double?
		var fontFamily: String?
		var isUnderlined: Bool?
		var isStruckThrough: Bool?
		var css = CSSStyle()
		/// The element's text size in points, for resolving `em` lengths.
		var fontSize = 0.0
		/// How many paragraphs have started inside the element, so its top border goes on the first.
		var paragraphCount = 0
		/// The style of content the book adds after the element, generated when it closes.
		var after: CSSStyle?
		var link: URL?
		var color: CGColor?
		var backgroundColor: CGColor?
		var listStyleType: String?
		var preservesWhitespace: Bool?
		var wraps: Bool?
		var wordSpacing: Double?
		var isInvisible: Bool?
		var hyphenates: Bool?
		var baselineShift: Double?
		var isOverlined: Bool?
	}

	/// The style that applies to text at the current point, after inheriting from every open element.
	private struct Style {
		var block = Block.paragraph
		var isBold = false
		var isItalic = false
		var fontScale = 1.0
		var alignment = CTTextAlignment.natural
		var superscript = 0
		var isPreformatted = false
		var dropCap: DropCapStyle?
		var smallCaps: CSSStyle.SmallCaps?
		var textTransform = CSSStyle.TextTransform.none
		/// In ems.
		var letterSpacing = 0.0
		/// A CSS `font-family` list, which may name fonts the book embeds.
		var fontFamily: String?
		var isUnderlined = false
		var isStruckThrough = false
		var link: URL?
		var color: CGColor?
		/// From inline elements only; a block's background is drawn behind its paragraphs instead.
		var highlight: CGColor?
		var wraps = true
		/// In ems.
		var wordSpacing = 0.0
		var isInvisible = false
		var hyphenates = true
		/// In ems, raising or lowering the text.
		var baselineShift = 0.0
		var isOverlined = false
	}

	/// Marks text drawn with a line over it. The page draws the line.
	static let overlineAttribute = NSAttributedString.Key("VellumOverline")
	/// Marks text whose words shouldn't be hyphenated or, for `false` wrapping, broken between.
	static let noHyphenationAttribute = NSAttributedString.Key("VellumNoHyphenation")
	static let noWrapAttribute = NSAttributedString.Key("VellumNoWrap")

	/// Marks text to strike through. Core Text has no attribute for it, so the page draws the line.
	static let strikethroughAttribute = NSAttributedString.Key("VellumStrikethrough")
	/// A color filled behind a run of text, from an inline element's background. The page draws it.
	static let highlightAttribute = NSAttributedString.Key("VellumHighlight")

	private static let blockNames: Set<String> = [
		"p", "div", "section", "article", "header", "footer", "aside", "nav", "main", "figure", "figcaption",
		"center", "address", "dd", "dt", "td", "th", "caption", "ul", "ol", "dl", "table", "tr", "body",
	]
	private static let skippedNames: Set<String> = ["title", "script", "noscript", "template"]
	private static let lineSeparator = "\u{2028}"
	private static let objectReplacement = "\u{FFFC}"
	private static let space: unichar = 0x20
	private static let newline: unichar = 0x0A
	private static let lineSeparatorCharacter: unichar = 0x2028
	private static let tabCharacter: unichar = 0x09

	private let file: URL
	private let typography: ReaderTypography
	private let textArea: CGSize
	private let styleSheets: StyleSheetCache

	private var styleSheet = StyleSheet()
	private let output = NSMutableAttributedString()
	private var anchors: [String: Int] = [:]
	private var elements: [Element] = []
	private var skipDepth = 0
	private var styleText: String?
	/// Set when a paragraph's style gives its first letter a drop cap, until that letter arrives.
	private var pendingDropCap: DropCapStyle?

	private var fonts: [String: CTFont] = [:]
	private var attributeCache: [String: [NSAttributedString.Key: Any]] = [:]
	/// The format of the paragraph being built, made when its first text arrives.
	private var format: ParagraphFormat?
	/// The most recent paragraph's format, which takes the bottom margins of blocks that close after it.
	private var lastFormat: ParagraphFormat?
	/// Top margins of blocks opened since the last paragraph, which the next paragraph starts with.
	private var pendingSpaceBefore = 0.0
	/// Set by a block that asks for a page break before it, or one that closed asking for one after.
	private var pendingPageBreak = false
	/// The tables being read, innermost last, and the row in progress.
	private var tables: [TableColumns] = []
	private var rowCellLengths: [Int]?
	private var cellStart = 0
	private static let tab = "\t"
	/// How many generated quotes are open, so nested quotes alternate marks.
	private var quoteDepth = 0
	/// The target of an `<a>` being opened, picked up by its element.
	private var pendingLink: URL?
	/// A list item's marker, waiting for the item's first text.
	private var pendingListMarker: String?

	private init(file: URL, typography: ReaderTypography, textArea: CGSize, styleSheets: StyleSheetCache) {
		self.file = file
		self.typography = typography
		self.textArea = textArea
		self.styleSheets = styleSheets
	}

	static func convert(_ file: URL, typography: ReaderTypography, textArea: CGSize, styleSheets: StyleSheetCache) -> Output {
		let converter = ChapterConverter(file: file, typography: typography, textArea: textArea, styleSheets: styleSheets)
		return converter.convert()
	}

	private func convert() -> Output {
		guard let data = try? Data(contentsOf: file) else { return Output(text: NSAttributedString(), anchors: [:]) }
		let markup = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""

		if let document = HTMLNode.parse(Data(HTMLEntities.xmlCompatible(markup).utf8)) {
			walk(document)
		} else {
			// Not well-formed XML, so fall back to the words alone rather than showing nothing.
			appendPlainText(from: markup)
		}

		trimTrailingWhitespace()

		return Output(text: output, anchors: anchors)
	}

	// MARK: Walking the document

	private func walk(_ node: HTMLNode) {
		start(node)
		for child in node.children {
			switch child {
			case .element(let element): walk(element)
			case .text(let text): foundText(text)
			}
		}
		end(node)
	}

	private func start(_ node: HTMLNode) {
		let name = node.name
		let attributes = node.attributes

		if skipDepth > 0 || Self.skippedNames.contains(name) {
			skipDepth += 1
			return
		}

		switch name {
		case "style":
			styleText = ""
			return
		case "link":
			if attributes["rel"]?.lowercased().contains("stylesheet") == true, let href = attributes["href"], let url = resolve(href),
			   attributes["media"].map({ MediaQuery.matches($0, viewport: styleSheets.viewport) }) ?? true {
				styleSheet.merge(styleSheets.sheet(at: url))
			}
			return
		case "br":
			if !isInTableCell || output.length > cellStart {
				appendText(Self.lineSeparator, collapsingWhitespace: false)
			}
			return
		case "hr":
			appendRule()
			return
		case "img", "image":
			if let source = attributes["src"] ?? attributes["href"] ?? attributes["xlink:href"] {
				var css = styleSheet.style(for: node)
				if let inline = attributes["style"] {
					css.merge(CSSStyle(declarations: inline))
				}
				if !css.isHidden {
					appendImage(source, css: css, attributes: attributes)
				}
			}
			return
		default:
			break
		}

		if name == "a", let href = attributes["href"] ?? attributes["xlink:href"] {
			pendingLink = linkTarget(href)
		}

		var css = styleSheet.style(for: node)
		if let inline = attributes["style"] {
			css.merge(CSSStyle(declarations: inline))
		}

		if css.isHidden {
			skipDepth = 1
			return
		}

		if let id = attributes["id"] ?? attributes["name"] {
			anchors[id] = output.length
		}

		if typography.styles.bookTables, startTableElement(name) {
			elements.append(makeElement(name: name, css: css))
			return
		}

		let element = makeElement(name: name, css: css)
		if element.block != nil {
			finishParagraph()
			if !isInTableCell, typography.styles.bookDropCaps, let dropCap = DropCapStyle(styleSheet.style(for: node, pseudoElement: "first-letter")) {
				dropCap.fitsGlyphs = true
				pendingDropCap = dropCap
			}
		}
		elements.append(element)
		elements[elements.count - 1].fontSize = typography.size * currentStyle().fontScale

		if typography.styles.bookTextEffects {
			if let before = styleSheet.style(for: node, pseudoElement: "before").generatedContent(quoteDepth: &quoteDepth) {
				appendText(before, collapsingWhitespace: false)
			}
			elements[elements.count - 1].after = styleSheet.style(for: node, pseudoElement: "after")
		}

		if element.block != nil {
			pendingSpaceBefore = max(pendingSpaceBefore, verticalSpace(of: elements[elements.count - 1], side: "top"))
			if typography.styles.bookPageBreaks, css.breaksPageBefore {
				pendingPageBreak = true
			}
		}

		if name == "li" {
			appendListMarker()
		}
	}

	private func end(_ node: HTMLNode) {
		let name = node.name

		if skipDepth > 0 {
			skipDepth -= 1
			return
		}

		if name == "style", let css = styleText {
			styleSheets.fonts.load(css: css, relativeTo: file)
			styleSheet.merge(StyleSheet(css: css, viewport: styleSheets.viewport))
			styleText = nil
			return
		}

		// Tolerate slightly mismatched markup by closing back to the matching element.
		guard let index = elements.lastIndex(where: { $0.name == name }) else { return }

		if let after = elements[index].after?.generatedContent(quoteDepth: &quoteDepth) {
			appendText(after, collapsingWhitespace: false)
		}

		if typography.styles.bookTables, endTableElement(name) {
			elements.removeSubrange(index...)
			return
		}
		let closed = elements[index...]
		let closesBlock = closed.contains { $0.block != nil }
		for element in closed.reversed() where element.block != nil {
			if typography.styles.bookPageBreaks, element.css.breaksPageAfter {
				pendingPageBreak = true
			}
			if let lastFormat {
				lastFormat.spaceAfter = max(lastFormat.spaceAfter, verticalSpace(of: element, side: "bottom"))
				if typography.styles.bookBorders, element.paragraphCount > 0, let width = element.css.borderWidth("bottom") {
					lastFormat.borderBottom = max(lastFormat.borderBottom, width)
				}
			}
		}
		elements.removeSubrange(index...)

		// A block with a border but no text, like an empty div used as a rule, still draws its line.
		if typography.styles.bookBorders, let element = closed.first, element.block != nil, element.paragraphCount == 0,
		   let width = element.css.borderWidth("top") ?? element.css.borderWidth("bottom") {
			appendRuleLine(width: width)
		}

		if closesBlock {
			if name == "li" {
				pendingListMarker = nil
			}
			finishParagraph()
			pendingDropCap = nil
		}
	}

	private func foundText(_ string: String) {
		guard skipDepth == 0 else { return }

		if styleText != nil {
			styleText? += string
		} else if !elements.isEmpty {
			appendText(string, collapsingWhitespace: !currentStyle().isPreformatted)
		}
	}

	// MARK: Tables

	/// Rows become single paragraphs with their cells separated by tabs, which the typesetter lines up in columns.
	/// Returns whether the element was handled as part of a table.
	private func startTableElement(_ name: String) -> Bool {
		switch name {
		case "table":
			finishParagraph()
			tables.append(TableColumns())
			return true
		case "tr" where !tables.isEmpty:
			finishParagraph()
			rowCellLengths = []
			return true
		case "td", "th":
			guard !tables.isEmpty, var cells = rowCellLengths else { return false }
			if !cells.isEmpty {
				output.append(NSAttributedString(string: Self.tab, attributes: paragraphAttributes(for: currentStyle())))
			}
			cells.append(0)
			rowCellLengths = cells
			cellStart = output.length
			return true
		case "thead", "tbody", "tfoot", "colgroup", "col":
			return !tables.isEmpty
		default:
			return false
		}
	}

	private func endTableElement(_ name: String) -> Bool {
		switch name {
		case "table" where !tables.isEmpty:
			tables.removeLast()
			finishParagraph()
			return true
		case "tr" where rowCellLengths != nil:
			if let cells = rowCellLengths, let table = tables.last, let format {
				table.addRow(cellLengths: cells)
				format.table = table
				format.alignment = .natural
				format.firstLineIndent = 0
			}
			rowCellLengths = nil
			finishParagraph()
			return true
		case "td", "th":
			guard var cells = rowCellLengths, !cells.isEmpty else { return false }
			// Whitespace and line breaks at a cell's end would otherwise sit before the next cell's tab.
			while lastCharacter == Self.space || lastCharacter == Self.lineSeparatorCharacter, output.length > cellStart {
				output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1))
			}
			cells[cells.count - 1] = output.length - cellStart
			rowCellLengths = cells
			return true
		case "thead", "tbody", "tfoot", "colgroup", "col":
			return !tables.isEmpty
		default:
			return false
		}
	}

	// MARK: Elements and styles

	private func makeElement(name: String, css: CSSStyle) -> Element {
		var element = Element(name: name)

		switch name {
		case "h1", "h2", "h3", "h4", "h5", "h6":
			let level = Int(name.dropFirst()) ?? 1
			element.block = .heading(level)
			element.isBold = true
			element.fontScale = [1.6, 1.35, 1.2, 1.05, 1, 1][level - 1]
		case "blockquote":
			element.block = .quote
		case "li":
			element.block = .listItem
		case "pre":
			element.block = .preformatted
			element.isPreformatted = true
		case "b", "strong", "th":
			element.isBold = true
		case "u", "ins":
			element.isUnderlined = true
		case "s", "strike", "del":
			element.isStruckThrough = true
		case "i", "em", "cite", "var", "dfn":
			element.isItalic = true
		case "small":
			element.fontScale = 0.85
		case "big":
			element.fontScale = 1.2
		case "sup":
			element.superscript = 1
			element.fontScale = 0.75
		case "sub":
			element.superscript = -1
			element.fontScale = 0.75
		case "center":
			element.alignment = .center
		case "ol":
			element.isOrderedList = true
		default:
			break
		}

		if element.block == nil && Self.blockNames.contains(name) {
			element.block = .paragraph
		}

		element.isBold = css.isBold ?? element.isBold
		element.isItalic = css.isItalic ?? element.isItalic
		// With book text sizes off, only the reader's own sizes for headings, small print, and the like apply.
		if typography.styles.bookTextSizes {
			element.fontScale = css.fontScale ?? element.fontScale
		}
		element.alignment = css.alignment ?? element.alignment

		if typography.styles.bookDropCaps {
			element.dropCap = DropCapStyle(css)
		} else if css.floatsLeft == true {
			// With drop caps off, the letter is set like the rest of the text.
			element.fontScale = nil
		}
		if typography.styles.bookTextEffects {
			element.smallCaps = css.smallCaps
			element.textTransform = css.textTransform
			element.letterSpacing = css.letterSpacing
			element.isUnderlined = css.isUnderlined ?? element.isUnderlined
			element.isStruckThrough = css.isStruckThrough ?? element.isStruckThrough
		}
		if typography.styles.bookFonts {
			element.fontFamily = css.properties["font-family"]
		}
		element.listStyleType = css.listStyleType
		element.preservesWhitespace = css.preservesWhitespace
		element.wraps = css.wraps
		element.isInvisible = css.isInvisible
		element.hyphenates = css.hyphenates
		if typography.styles.bookTextEffects {
			element.wordSpacing = css.wordSpacing
			element.baselineShift = css.baselineShift
			element.isOverlined = css.isOverlined
			element.superscript = css.verticalPosition ?? element.superscript
		}
		element.link = pendingLink
		pendingLink = nil
		if typography.styles.bookColors {
			element.color = css.color
			element.backgroundColor = css.backgroundColor.flatMap { $0.alpha > 0 ? $0 : nil }
		}
		if name == "pre" || name == "code" || name == "kbd" || name == "samp" || name == "tt" {
			element.fontFamily = element.fontFamily ?? "monospace"
		}
		element.css = css
		return element
	}

	private func currentStyle() -> Style {
		var style = Style()

		for element in elements {
			style.block = element.block ?? style.block
			style.isBold = element.isBold ?? style.isBold
			style.isItalic = element.isItalic ?? style.isItalic
			style.fontScale *= element.fontScale ?? 1
			style.alignment = element.alignment ?? style.alignment
			style.superscript = element.superscript ?? style.superscript
			style.isPreformatted = style.isPreformatted || element.isPreformatted
			style.dropCap = element.dropCap ?? style.dropCap
			if let smallCaps = element.smallCaps {
				style.smallCaps = smallCaps
			}
			style.textTransform = element.textTransform ?? style.textTransform
			style.letterSpacing = element.letterSpacing ?? style.letterSpacing
			style.fontFamily = element.fontFamily ?? style.fontFamily
			// Decorations add up: CSS can't remove one an outer element draws.
			style.isUnderlined = style.isUnderlined || element.isUnderlined == true
			style.isStruckThrough = style.isStruckThrough || element.isStruckThrough == true
			style.link = element.link ?? style.link
			style.color = element.color ?? style.color
			style.isPreformatted = element.preservesWhitespace ?? style.isPreformatted
			style.wraps = element.wraps ?? style.wraps
			style.wordSpacing = element.wordSpacing ?? style.wordSpacing
			style.isInvisible = element.isInvisible ?? style.isInvisible
			style.hyphenates = element.hyphenates ?? style.hyphenates
			// Shifts add up through nested elements; they aren't inherited.
			style.baselineShift += element.baselineShift ?? 0
			style.isOverlined = style.isOverlined || element.isOverlined == true
			if element.block == nil, let background = element.backgroundColor {
				style.highlight = background
			}
		}

		return style
	}

	private func attributes(for style: Style) -> [NSAttributedString.Key: Any] {
		// The drop cap's own size doesn't matter: the typesetter draws it at a size worked out from the lines it spans.
		var style = style
		if style.dropCap != nil {
			style.fontScale = 1
		}

		let key = "\(style.block)-\(style.isBold)-\(style.isItalic)-\(style.fontScale)-\(style.superscript)-\(style.letterSpacing)-\(style.fontFamily ?? "")-\(style.isUnderlined)-\(style.isStruckThrough)-\(style.link?.absoluteString ?? "")-\(Self.colorKey(style.color))-\(Self.colorKey(style.highlight))-\(style.wraps)-\(style.wordSpacing)-\(style.isInvisible)-\(style.hyphenates)-\(style.baselineShift)-\(style.isOverlined)"
		if let attributes = attributeCache[key] {
			return attributes
		}

		var attributes: [NSAttributedString.Key: Any] = [
			NSAttributedString.Key(kCTFontAttributeName as String): font(for: style),
			// Standard ligatures, like fi and fl, wherever the font has them.
			NSAttributedString.Key(kCTLigatureAttributeName as String): 1,
		]

		if style.superscript != 0 {
			attributes[NSAttributedString.Key(kCTSuperscriptAttributeName as String)] = style.superscript
		}

		if style.isUnderlined {
			attributes[NSAttributedString.Key(kCTUnderlineStyleAttributeName as String)] = CTUnderlineStyle.single.rawValue
		}

		if style.isStruckThrough {
			attributes[Self.strikethroughAttribute] = true
		}

		if let link = style.link {
			attributes[Self.linkAttribute] = link
		}

		if let color = style.color {
			attributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color
		} else {
			// Text without a color of its own takes the theme's, so changing themes doesn't need a new layout.
			attributes[NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String)] = true
		}

		if let highlight = style.highlight {
			attributes[Self.highlightAttribute] = highlight
		}

		if style.isInvisible {
			// Takes its space, as CSS visibility does, but isn't seen.
			attributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = CGColor(gray: 0, alpha: 0)
			attributes[NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String)] = nil
			attributes[Self.highlightAttribute] = nil
		}

		if style.baselineShift != 0 {
			attributes[NSAttributedString.Key(kCTBaselineOffsetAttributeName as String)] = style.baselineShift * typography.size * style.fontScale
		}

		if style.isOverlined {
			attributes[Self.overlineAttribute] = true
		}

		if !style.hyphenates {
			attributes[Self.noHyphenationAttribute] = true
		}

		if !style.wraps {
			attributes[Self.noWrapAttribute] = true
		}

		if style.letterSpacing != 0 {
			attributes[NSAttributedString.Key(kCTTrackingAttributeName as String)] = style.letterSpacing * typography.size * style.fontScale
		}

		attributeCache[key] = attributes
		return attributes
	}

	/// The attributes for text in the current paragraph, starting the paragraph's format if this is its first text.
	private func paragraphAttributes(for style: Style) -> [NSAttributedString.Key: Any] {
		var attributes = attributes(for: style)
		attributes[Self.formatAttribute] = format ?? makeFormat(for: style)
		return attributes
	}

	private func font(for style: Style) -> CTFont {
		let size = (typography.size * style.fontScale).rounded()
		let key = "\(size)-\(style.isBold)-\(style.isItalic)-\(style.fontFamily ?? "")"
		if let font = fonts[key] {
			return font
		}

		if let families = style.fontFamily, let font = styleSheets.fonts.font(families: families, size: size, isBold: style.isBold, isItalic: style.isItalic) {
			fonts[key] = font
			return font
		}

		var font = Self.genericFont(families: style.fontFamily, size: size) ?? typography.font.font(size: size)
		var traits = CTFontSymbolicTraits()
		if style.isBold { traits.insert(.traitBold) }
		if style.isItalic { traits.insert(.traitItalic) }
		if !traits.isEmpty, let styled = CTFontCreateCopyWithSymbolicTraits(font, CTFontGetSize(font), nil, traits, traits) {
			font = styled
		}

		fonts[key] = font
		return font
	}

	/// A system font for a family list whose first generic family is monospace or sans-serif. Serif and named
	/// families the book doesn't embed fall back to the reader's font, which is itself a serif.
	private static func genericFont(families: String?, size: Double) -> CTFont? {
		guard let families else { return nil }

		for family in families.lowercased().split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }) {
			switch family {
			case "monospace", "monospaced", "courier", "courier new", "freefontmono", "menlo", "consolas":
				return CTFontCreateWithName("Menlo-Regular" as CFString, size * 0.9, nil)
			case "sans-serif", "helvetica", "arial", "freefontsans", "verdana":
				return CTFontCreateUIFontForLanguage(.system, size, nil)
			case "serif", "georgia", "times", "times new roman", "freefontserif":
				return nil
			default:
				continue
			}
		}
		return nil
	}

	private static func colorKey(_ color: CGColor?) -> String {
		color?.components?.map { "\($0)" }.joined(separator: ",") ?? ""
	}

	/// The format for a paragraph starting now, from its block's defaults and the styles of the elements it's in.
	private func makeFormat(for style: Style) -> ParagraphFormat {
		let format = ParagraphFormat()
		let styles = typography.styles
		let size = typography.size
		let fontSize = size * style.fontScale

		format.lineHeight = typography.lineHeight
		var hasBookLineHeight = false
		if styles.bookLineHeight, let lineHeight = bookLineHeight(fontSize: fontSize, style: style) {
			format.lineHeight = lineHeight
			hasBookLineHeight = true
		}

		if styles.bookParagraphSpacing {
			// Book margins, gathered from the blocks that opened before this paragraph and closed after it.
			format.spaceBefore = pendingSpaceBefore
		} else {
			let spacing = size * typography.paragraphSpacing
			format.spaceAfter = spacing
			format.spaceBefore = 0

			switch style.block {
			case .heading:
				format.spaceBefore = max(format.spaceBefore, size * 1.2)
				format.spaceAfter = max(spacing, size * 0.5)
			case .listItem:
				format.spaceAfter = spacing / 2
			case .image:
				format.spaceBefore = max(format.spaceBefore, size * 0.3)
				format.spaceAfter = max(spacing, size * 0.3)
			case .paragraph, .preformatted, .quote:
				break
			}
		}
		pendingSpaceBefore = 0
		format.breaksPageBefore = pendingPageBreak
		pendingPageBreak = false

		if styles.bookPageBreaks {
			// Inherited, so the innermost element that sets each wins.
			format.widows = elements.last { $0.block != nil && $0.css.widows != nil }?.css.widows ?? 2
			format.orphans = elements.last { $0.block != nil && $0.css.orphans != nil }?.css.orphans ?? 2
			format.keepWithNext = isHeading(style.block) || elements.contains { $0.block != nil && $0.css.avoidsBreakAfter }
			format.avoidsBreakInside = elements.contains { $0.block != nil && $0.css.avoidsBreakInside }
		} else {
			format.widows = 1
			format.orphans = 1
		}

		switch style.block {
		case .heading:
			// Headings are set a little tighter than body text, unless the book says otherwise.
			if !hasBookLineHeight {
				format.lineHeight = max(format.lineHeight * 0.9, 1)
			}
		case .quote:
			format.indent = size * 1.5
		case .listItem:
			format.indent = size * 1.5
			// The marker hangs to the left of the item's text.
			format.firstLineIndent = -size
		case .image:
			format.lineHeight = 1
		case .paragraph, .preformatted:
			break
		}

		if styles.bookBorders {
			applyBorders(to: format)
		}

		if styles.bookColors, let index = elements.lastIndex(where: { $0.block != nil && $0.backgroundColor != nil }) {
			// The innermost block with a background fills its whole box: inside the margins of it and the blocks
			// around it, but including its padding.
			let outer = elements[..<index].filter { $0.block != nil && $0.name != "body" && $0.name != "html" }
			let block = elements[index]
			format.backgroundColor = block.backgroundColor
			if styles.bookMargins {
				let width = textArea.width
				format.backgroundLeft = outer.reduce(0) { $0 + horizontalSpace(of: $1, side: "left") } + (block.css.length("margin-left")?.points(fontSize: block.fontSize, width: width) ?? 0)
				format.backgroundRight = outer.reduce(0) { $0 + horizontalSpace(of: $1, side: "right") } + (block.css.length("margin-right")?.points(fontSize: block.fontSize, width: width) ?? 0)
			}
		}

		if styles.bookMargins {
			// The book's margins and padding, added up through every block the paragraph is in.
			let blocks = elements.filter { $0.block != nil && $0.name != "body" && $0.name != "html" }
			format.indent = blocks.reduce(0) { $0 + horizontalSpace(of: $1, side: "left") }
			format.rightIndent = blocks.reduce(0) { $0 + horizontalSpace(of: $1, side: "right") }
		}

		var alignment = style.alignment
		if style.block == .image {
			// Placed by the alignment around it, like any block.
		} else if alignment == .natural || alignment == .justified, style.block != .preformatted, !isHeading(style.block) {
			switch styles.justification {
			case .book: break
			case .justified: alignment = .justified
			case .ragged: alignment = .natural
			}
		}
		format.alignment = alignment

		// Text indent is inherited, so the innermost element that sets it wins.
		// Indents, line heights, and the like belong to blocks, and inline elements inside them can't change them.
		if typography.styles.bookIndents, let block = elements.last(where: { $0.block != nil && $0.css.length("text-indent") != nil }), let indent = block.css.length("text-indent") {
			format.firstLineIndent = indent.points(fontSize: block.fontSize, width: textArea.width)
		}

		self.format = format
		lastFormat = format
		return format
	}

	/// Borders on the innermost block draw around this paragraph. A border on an enclosing block is drawn on its
	/// first paragraph (top), last paragraph (bottom, set when it closes), and every paragraph (left).
	private func applyBorders(to format: ParagraphFormat) {
		for (index, element) in elements.enumerated() where element.block != nil {
			let isInnermost = !elements[(index + 1)...].contains { $0.block != nil }
			if isInnermost || element.paragraphCount == 0, let width = element.css.borderWidth("top") {
				format.borderTop = max(format.borderTop, width)
			}
			if let width = element.css.borderWidth("left") {
				format.borderLeft = max(format.borderLeft, width)
			}
			elements[index].paragraphCount += 1
		}
	}

	/// The space a block wants beside it, from its margin and padding on that side.
	private func horizontalSpace(of element: Element, side: String) -> Double {
		let fontSize = element.fontSize
		let margin = (element.css.length("margin-\(side)") ?? Self.defaultInset(for: element.name, side: side, property: "margin"))?.points(fontSize: fontSize, width: textArea.width) ?? 0
		let padding = (element.css.length("padding-\(side)") ?? Self.defaultInset(for: element.name, side: side, property: "padding"))?.points(fontSize: fontSize, width: textArea.width) ?? 0
		return margin + padding
	}

	/// Browsers' default side margins and padding, for books that don't set their own.
	private static func defaultInset(for name: String, side: String, property: String) -> CSSLength? {
		switch (name, side, property) {
		case ("blockquote", _, "margin"), ("figure", _, "margin"): CSSLength("40px")
		case ("ul", "left", "padding"), ("ol", "left", "padding"), ("dd", "left", "margin"): CSSLength("40px")
		default: nil
		}
	}

	/// The book's line height for text in the current elements, as a multiple of the font's natural line height.
	private func bookLineHeight(fontSize: Double, style: Style) -> Double? {
		// Line height is inherited, so the innermost block that sets it wins. Lengths are fixed where they're set.
		guard
			let block = elements.last(where: { $0.block != nil && $0.css.properties["line-height"] != nil }),
			let value = block.css.properties["line-height"]?.lowercased()
		else { return nil }

		let cssLineHeight: Double
		if let number = Double(value) {
			cssLineHeight = number
		} else if let length = CSSLength(value), length.unit != .percent {
			cssLineHeight = length.points(fontSize: block.fontSize, width: 0) / fontSize
		} else if let length = CSSLength(value) {
			cssLineHeight = length.value / 100
		} else {
			return nil
		}

		// CSS measures line height against the text size; the typesetter against the font's ascent plus descent.
		let font = font(for: style)
		let natural = (CTFontGetAscent(font) + CTFontGetDescent(font)) / CTFontGetSize(font)
		return cssLineHeight > 0 ? cssLineHeight / natural : nil
	}

	/// The space a block wants above or below it, from its margin and padding on that side.
	private func verticalSpace(of element: Element, side: String) -> Double {
		let fontSize = element.fontSize
		let margin = (element.css.length("margin-\(side)") ?? Self.defaultMargin(for: element.name))?.points(fontSize: fontSize, width: textArea.width) ?? 0
		let padding = element.css.length("padding-\(side)")?.points(fontSize: fontSize, width: textArea.width) ?? 0
		return typography.styles.bookParagraphSpacing ? max(margin + padding, 0) : 0
	}

	/// Browsers' default margins, for books that don't set their own.
	private static func defaultMargin(for name: String) -> CSSLength? {
		switch name {
		case "p", "blockquote", "ul", "ol", "dl", "pre", "figure", "h4": CSSLength("1em")
		case "h1": CSSLength("0.67em")
		case "h2": CSSLength("0.83em")
		case "h3": CSSLength("1em")
		case "h5", "h6": CSSLength("1.5em")
		default: nil
		}
	}

	private func isHeading(_ block: Block) -> Bool {
		if case .heading = block { true } else { false }
	}

	// MARK: Building the text

	private func appendText(_ text: String, collapsingWhitespace: Bool) {
		var text = text

		if collapsingWhitespace {
			text = Self.collapsingWhitespace(in: text, dropLeadingSpace: endsAtLineStart || lastCharacter == Self.space || lastCharacter == Self.tabCharacter)
		} else {
			text = text.replacing("\r\n", with: Self.lineSeparator).replacing("\n", with: Self.lineSeparator)
		}

		guard !text.isEmpty else { return }

		if let marker = pendingListMarker {
			pendingListMarker = nil
			output.append(NSAttributedString(string: marker, attributes: paragraphAttributes(for: currentStyle())))
		}

		let style = currentStyle()
		let isParagraphStart = endsAtLineStart
		text = transformed(text, style.textTransform)

		// A drop cap only works at the very start of a paragraph; anywhere else, the letters stay in the line.
		if let dropCap = style.dropCap, isParagraphStart {
			output.append(self.dropCap(text, dropCap, style: style))
			return
		}

		if let dropCap = pendingDropCap, isParagraphStart {
			pendingDropCap = nil

			// Like CSS's first-letter, the drop cap takes the first letter plus any punctuation before it, such as a quote mark.
			var letters = text.prefix { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
			if let letter = text.dropFirst(letters.count).first, letter.isLetter || letter.isNumber {
				letters = text.prefix(letters.count + 1)
				output.append(self.dropCap(String(letters), dropCap, style: style))
				text = String(text.dropFirst(letters.count))
				guard !text.isEmpty else { return }
			}
		}

		if let smallCaps = style.smallCaps {
			appendSmallCaps(text, smallCaps, style: style)
		} else {
			let start = output.length
			output.append(NSAttributedString(string: text, attributes: paragraphAttributes(for: style)))
			if style.wordSpacing != 0 {
				// Word spacing widens each space, so line breaking measures it and justification adds to it.
				let added = style.wordSpacing * typography.size * style.fontScale
				let string = output.mutableString
				for index in start..<output.length where string.character(at: index) == Self.space {
					output.addAttribute(NSAttributedString.Key(kCTKernAttributeName as String), value: added, range: NSRange(location: index, length: 1))
				}
			}
		}
	}

	private func transformed(_ text: String, _ transform: CSSStyle.TextTransform) -> String {
		switch transform {
		case .none:
			return text
		case .uppercase:
			return text.uppercased()
		case .lowercase:
			return text.lowercased()
		case .capitalize:
			// A word can be split across elements, so whether a letter starts one depends on the text before it.
			var startsWord = lastCharacter.map { Character(UnicodeScalar($0) ?? " ").isWhitespace } ?? true
			return String(text.map { character in
				defer { startsWord = character.isWhitespace || character == "—" || character == "-" }
				return startsWord && character.isLetter ? Character(character.uppercased()) : character
			})
		}
	}

	/// Small capitals are made by setting letters as capitals at a smaller size, which works with any font.
	private func appendSmallCaps(_ text: String, _ smallCaps: CSSStyle.SmallCaps, style: Style) {
		var small = style
		small.fontScale *= 0.78
		let normalAttributes = paragraphAttributes(for: style)
		let smallAttributes = paragraphAttributes(for: small)

		var run = ""
		var isSmall = false
		func flush() {
			guard !run.isEmpty else { return }
			output.append(NSAttributedString(string: run, attributes: isSmall ? smallAttributes : normalAttributes))
			run = ""
		}

		for character in text {
			let shrinks = character.isLetter && (smallCaps == .all || character.isLowercase)
			if shrinks != isSmall {
				flush()
				isSmall = shrinks
			}
			run += shrinks ? character.uppercased() : String(character)
		}
		flush()
	}

	private func dropCap(_ letters: String, _ dropCap: DropCapStyle, style: Style) -> NSAttributedString {
		var attributes = paragraphAttributes(for: style)
		attributes[Self.dropCapAttribute] = dropCap
		return NSAttributedString(string: letters, attributes: attributes)
	}

	/// Collapses runs of HTML whitespace into single spaces. Written out by hand because this runs for every
	/// piece of text in a book, and a regular expression here made opening long books take many seconds.
	private static func collapsingWhitespace(in text: String, dropLeadingSpace: Bool) -> String {
		var result = String.UnicodeScalarView()
		var isInWhitespace = dropLeadingSpace

		for scalar in text.unicodeScalars {
			switch scalar {
			case " ", "\t", "\n", "\r", "\u{0C}":
				if !isInWhitespace {
					result.append(" ")
					isInWhitespace = true
				}
			default:
				result.append(scalar)
				isInWhitespace = false
			}
		}

		return String(result)
	}

	/// The last character so far. Read through `NSString`, because `output.string` copies the whole chapter.
	private var lastCharacter: unichar? {
		output.length > 0 ? output.mutableString.character(at: output.length - 1) : nil
	}

	private var endsAtLineStart: Bool {
		lastCharacter == nil || lastCharacter == Self.newline || lastCharacter == Self.lineSeparatorCharacter
	}

	/// Inside a table cell, blocks only start new lines within the cell, so the row stays one paragraph.
	private var isInTableCell: Bool {
		rowCellLengths?.isEmpty == false
	}

	/// Ends the current paragraph. The newline takes the paragraph's style, as Core Text expects.
	private func finishParagraph() {
		if isInTableCell {
			if output.length > cellStart, lastCharacter != Self.lineSeparatorCharacter {
				output.append(NSAttributedString(string: Self.lineSeparator, attributes: paragraphAttributes(for: currentStyle())))
			}
			return
		}

		format = nil
		guard output.length > 0 else { return }

		while lastCharacter == Self.space {
			output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1))
		}
		guard output.length > 0, lastCharacter != Self.newline else { return }

		let attributes = output.attributes(at: output.length - 1, effectiveRange: nil)
		output.append(NSAttributedString(string: "\n", attributes: attributes))
	}

	/// The marker for a list item, as the list's `list-style-type` says: a bullet, a number, a letter, a Roman
	/// numeral, or nothing.
	private func appendListMarker() {
		guard let listIndex = elements.dropLast().lastIndex(where: { $0.name == "ul" || $0.name == "ol" }) else {
			appendText("• ", collapsingWhitespace: false)
			return
		}

		elements[listIndex].listCount += 1
		let number = elements[listIndex].listCount
		// The innermost list style set on the list, its items, or anything in between; else the list's own default.
		let type = elements[listIndex...].last { $0.listStyleType != nil }?.listStyleType
			?? elements[..<listIndex].last { $0.listStyleType != nil }?.listStyleType
			?? (elements[listIndex].isOrderedList ? "decimal" : "disc")

		let marker: String? = switch type {
		case "none": nil
		case "disc": "•"
		case "circle": "◦"
		case "square": "▪"
		case "decimal": "\(number)."
		case "decimal-leading-zero": String(format: "%02d.", number)
		case "lower-alpha", "lower-latin": "\(Self.alphabetic(number))."
		case "upper-alpha", "upper-latin": "\(Self.alphabetic(number).uppercased())."
		case "lower-roman": "\(Self.roman(number))."
		case "upper-roman": "\(Self.roman(number).uppercased())."
		case "lower-greek": "\(Self.greek(number))."
		default: elements[listIndex].isOrderedList ? "\(number)." : "•"
		}

		// Held until the item's first text, so it sits on that line even when the text is in a block inside the item.
		pendingListMarker = marker.map { $0 + " " }
	}

	private static func alphabetic(_ number: Int) -> String {
		var number = number, result = ""
		while number > 0 {
			number -= 1
			result = String(UnicodeScalar(UInt8(97 + number % 26))) + result
			number /= 26
		}
		return result
	}

	private static func roman(_ number: Int) -> String {
		let values = [(1000, "m"), (900, "cm"), (500, "d"), (400, "cd"), (100, "c"), (90, "xc"), (50, "l"), (40, "xl"), (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
		var number = number, result = ""
		for (value, letters) in values {
			while number >= value {
				result += letters
				number -= value
			}
		}
		return result
	}

	private static func greek(_ number: Int) -> String {
		let letters = Array("αβγδεζηθικλμνξοπρστυφχψω")
		return String(letters[(number - 1) % letters.count])
	}


	/// A paragraph holding nothing but a horizontal line.
	private func appendRuleLine(width: Double) {
		finishParagraph()
		let format = makeFormat(for: currentStyle())
		format.borderTop = width
		format.alignment = .natural
		output.append(NSAttributedString(string: "\u{200B}\n", attributes: paragraphAttributes(for: currentStyle())))
		self.format = nil
	}

	private func appendRule() {
		finishParagraph()
		var style = currentStyle()
		style.alignment = .center
		output.append(NSAttributedString(string: "⁂\n", attributes: paragraphAttributes(for: style)))
		format = nil
	}

	/// An image, sized as CSS sizes it: its `width` and `height` (from styles or attributes), else its own size in
	/// CSS pixels, limited by `max-width` and `max-height`. Like any inline element it sits in the line, unless the
	/// book makes it a block, which then takes its own line and is placed by the alignment of the text around it.
	private func appendImage(_ source: String, css: CSSStyle, attributes: [String: String]) {
		guard
			let url = resolve(source),
			let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
			let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
		else { return }

		let natural = CGSize(width: image.width, height: image.height)
		let fontSize = typography.size * currentStyle().fontScale
		// Percentages are of the column; heights use the page, as a book's 100% height means a full page.
		func length(_ property: String, of reference: Double) -> Double? {
			guard let value = css.length(property) ?? attributes[property].flatMap({ CSSLength($0) ?? Double($0).map { CSSLength("\($0)px")! } }) else { return nil }
			let points = value.unit == .percent ? value.value / 100 * reference : value.points(fontSize: fontSize, width: reference)
			return points > 0 ? points : nil
		}

		var width = length("width", of: textArea.width)
		var height = length("height", of: textArea.height)
		switch (width, height) {
		case (nil, nil): width = natural.width; height = natural.height
		case (let w?, nil): height = w * natural.height / natural.width
		case (nil, let h?): width = h * natural.width / natural.height
		default: break
		}

		var size = CGSize(width: width ?? natural.width, height: height ?? natural.height)
		let maxWidth = length("max-width", of: textArea.width), maxHeight = length("max-height", of: textArea.height)
		// A page can't scroll, so an image taller or wider than the page would be cut off; those alone shrink to fit.
		let page = min(textArea.width / size.width, textArea.height / size.height)
		let limit = min(maxWidth.map { $0 / size.width } ?? 1, maxHeight.map { $0 / size.height } ?? 1, page, 1)
		size = CGSize(width: (size.width * limit).rounded(.down), height: (size.height * limit).rounded(.down))
		guard size.width >= 1, size.height >= 1 else { return }

		let run = ImageRun(image: image, size: size)
		guard let delegate = run.makeRunDelegate() else { return }

		let display = css.properties["display"]?.lowercased()
		let isBlock = display == "block" || display == "table" || display == "flex"
		var style = currentStyle()
		if isBlock {
			finishParagraph()
			style.block = .image
			style.alignment = css.properties["margin-left"]?.lowercased() == "auto" && css.properties["margin-right"]?.lowercased() == "auto" ? .center : style.alignment
		}

		var imageAttributes = paragraphAttributes(for: style)
		imageAttributes[NSAttributedString.Key(kCTRunDelegateAttributeName as String)] = delegate
		imageAttributes[Self.imageAttribute] = run
		output.append(NSAttributedString(string: Self.objectReplacement, attributes: imageAttributes))

		if isBlock {
			output.append(NSAttributedString(string: "\n", attributes: paragraphAttributes(for: style)))
			format = nil
		}
	}


	/// For chapters that aren't well-formed XML: drop the markup and keep each paragraph's words.
	private func appendPlainText(from markup: String) {
		let body = markup
			.replacing(/(?is)<(head|script|style)\b.*?<\/\1>/, with: "")
			.replacing(/(?i)<\/(p|div|h[1-6]|li|blockquote)>|<br\s*\/?>/, with: "\n")
			.replacing(/<[^>]*>/, with: "")

		let style = Style()
		for line in HTMLEntities.decoded(body).split(separator: "\n") {
			let text = line.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
			guard !text.isEmpty else { continue }
			output.append(NSAttributedString(string: text + "\n", attributes: paragraphAttributes(for: style)))
			format = nil
		}
	}

	private func trimTrailingWhitespace() {
		while let last = lastCharacter, [Self.space, Self.newline, Self.lineSeparatorCharacter, 9].contains(last) {
			output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1))
		}
	}

	/// Where a link goes, keeping its fragment: a file in the book, or a web or mail address.
	private func linkTarget(_ href: String) -> URL? {
		let href = href.trimmingCharacters(in: .whitespaces)
		if let url = URL(string: href), let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
			return url
		}
		guard let url = URL(string: href, relativeTo: file), url.isFileURL else { return nil }
		return url.absoluteURL
	}

	/// Resolves a link from the chapter, which may be percent-encoded and carry a `#fragment`.
	private func resolve(_ href: String) -> URL? {
		let path = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
		guard !path.isEmpty, let url = URL(string: path, relativeTo: file), url.isFileURL else { return nil }
		return url.absoluteURL.standardizedFileURL
	}
}
