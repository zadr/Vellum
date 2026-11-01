import CoreText
import Foundation

/// Sets a chapter's text into lines: chooses breaks with `LineBreaker`, hyphenating where it helps,
/// then builds each line with Core Text. Justified lines are filled out by widening the spaces between words only.
nonisolated struct ParagraphTypesetter {
	private struct Paragraph {
		var alignment = CTTextAlignment.natural
		var firstLineIndent = 0.0
		var indent = 0.0
		var spaceBefore = 0.0
		var spaceAfter = 0.0
		var lineHeight = 1.0
	}

	/// Where a line ends, as found by the line breaker.
	private struct Break {
		/// Where the line's text ends, before any spaces.
		var end: Int
		/// Where the next line's text starts.
		var next: Int
		var addsHyphen: Bool
		/// The paragraph or a forced line break ends here, so the line isn't stretched.
		var endsParagraph: Bool
	}

	/// A breakable spot and the text positions around it.
	private struct Position {
		var end: Int
		var next: Int
		var addsHyphen = false
	}

	private static let space: unichar = 0x20
	private static let lineSeparator: unichar = 0x2028
	let width: Double
	let hyphenator = Hyphenator()

	/// Every line of a chapter, in order.
	func lines(for text: NSAttributedString) -> [TypesetLine] {
		let string = text.string as NSString
		var lines = [TypesetLine]()
		var previousSpaceAfter = 0.0
		var start = 0

		while start < string.length {
			let newline = string.range(of: "\n", range: NSRange(location: start, length: string.length - start))
			let end = newline.location == NSNotFound ? string.length : newline.location

			if end > start {
				let paragraph = Self.paragraph(at: start, in: text)
				let range = NSRange(location: start, length: end - start)
				lines += setParagraph(text.attributedSubstring(from: range), style: paragraph, offset: start, spaceBefore: previousSpaceAfter + paragraph.spaceBefore)
				previousSpaceAfter = paragraph.spaceAfter
			}

			start = end + 1
		}

		return lines
	}

	// MARK: Paragraphs

	private func setParagraph(_ text: NSAttributedString, style: Paragraph, offset: Int, spaceBefore: Double) -> [TypesetLine] {
		let string = text.string as NSString
		let offsets = Self.characterOffsets(of: CTLineCreateWithAttributedString(text), length: string.length)
		let isJustified = style.alignment == .justified

		func lineWidth(_ line: Int) -> Double {
			max(width - (line == 0 ? style.firstLineIndent : style.indent), 1)
		}

		// Like TeX: try without hyphenation first, then with it, then accept loose lines; Core Text's own breaking is the last resort.
		var breaks: [Break]?
		for (hyphenate, tolerance) in [(false, 1.5), (true, 3.0), (true, 20.0)] {
			let (items, positions) = Self.items(for: text, string: string, offsets: offsets, isJustified: isJustified, hyphenator: hyphenate ? hyphenator : nil)
			if let indices = LineBreaker.breaks(items, lineWidth: lineWidth, tolerance: tolerance) {
				breaks = indices.map { index in
					let position = positions[index]
					return Break(end: position.end, next: position.next, addsHyphen: position.addsHyphen, endsParagraph: items[index].penalty == -.infinity)
				}
				break
			}
		}

		let lineBreaks = breaks ?? Self.greedyBreaks(for: text, string: string, lineWidth: lineWidth)

		var lines = [TypesetLine]()
		var start = 0
		for lineBreak in lineBreaks {
			lines.append(makeLine(text, string: string, start: start, lineBreak: lineBreak, index: lines.count, style: style, offset: offset, lineWidth: lineWidth(lines.count), spaceBefore: lines.isEmpty ? spaceBefore : 0))
			start = lineBreak.next
		}
		return lines
	}

	private static func paragraph(at index: Int, in text: NSAttributedString) -> Paragraph {
		var paragraph = Paragraph()
		guard let attribute = text.attribute(NSAttributedString.Key(kCTParagraphStyleAttributeName as String), at: index, effectiveRange: nil) else { return paragraph }

		let style = attribute as! CTParagraphStyle
		func value(_ specifier: CTParagraphStyleSpecifier) -> Double {
			var value: CGFloat = 0
			CTParagraphStyleGetValueForSpecifier(style, specifier, MemoryLayout<CGFloat>.size, &value)
			return value
		}

		CTParagraphStyleGetValueForSpecifier(style, .alignment, MemoryLayout<CTTextAlignment>.size, &paragraph.alignment)
		paragraph.firstLineIndent = value(.firstLineHeadIndent)
		paragraph.indent = value(.headIndent)
		paragraph.spaceBefore = value(.paragraphSpacingBefore)
		paragraph.spaceAfter = value(.paragraphSpacing)
		paragraph.lineHeight = max(value(.lineHeightMultiple), 1)
		return paragraph
	}

	// MARK: Breaking

	/// The paragraph as boxes, glue, and penalties, plus the text positions for each item should a line break there.
	private static func items(for text: NSAttributedString, string: NSString, offsets: [Double], isJustified: Bool, hyphenator: Hyphenator?) -> ([LineBreaker.Item], [Position]) {
		var items = [LineBreaker.Item]()
		var positions = [Position]()
		let length = string.length

		func x(_ index: Int) -> Double {
			offsets[index]
		}

		func append(_ item: LineBreaker.Item, end: Int, next: Int, addsHyphen: Bool = false) {
			items.append(item)
			positions.append(Position(end: end, next: next, addsHyphen: addsHyphen))
		}

		var index = 0
		while index < length {
			let character = string.character(at: index)

			if character == lineSeparator {
				append(LineBreaker.Item(kind: .glue, width: 0, stretch: 100_000), end: index, next: index)
				append(LineBreaker.Item(kind: .penalty, width: 0, penalty: -.infinity), end: index, next: index + 1)
				index += 1
				continue
			}

			if character == space {
				var end = index
				while end < length, string.character(at: end) == space {
					end += 1
				}
				let spaceWidth = x(end) - x(index)
				// Ragged text can't squeeze its spaces, but stretch still measures how unevenly lines fill.
				append(LineBreaker.Item(kind: .glue, width: spaceWidth, stretch: spaceWidth / 2, shrink: isJustified ? spaceWidth / 3 : 0), end: index, next: end)
				index = end
				continue
			}

			var end = index
			while end < length, string.character(at: end) != space, string.character(at: end) != lineSeparator {
				end += 1
			}

			var breakPoints = [(location: Int, addsHyphen: Bool)]()
			for location in (index + 1)..<max(end, index + 1) {
				// Words joined by dashes can break after the dash.
				if [0x2D, 0x2013, 0x2014].contains(string.character(at: location - 1)), location < end {
					breakPoints.append((location, false))
				}
			}
			if let hyphenator, breakPoints.isEmpty {
				breakPoints = hyphenator.points(in: string, word: index..<end).map { ($0, true) }
			}

			var pieceStart = index
			for point in breakPoints {
				append(LineBreaker.Item(kind: .box, width: x(point.location) - x(pieceStart)), end: point.location, next: point.location)
				let hyphenWidth = point.addsHyphen ? Self.hyphenWidth(in: text, at: point.location - 1) : 0
				append(LineBreaker.Item(kind: .penalty, width: hyphenWidth, penalty: point.addsHyphen ? 50 : 30, isFlagged: true), end: point.location, next: point.location, addsHyphen: point.addsHyphen)
				pieceStart = point.location
			}
			append(LineBreaker.Item(kind: .box, width: x(end) - x(pieceStart)), end: end, next: end)
			index = end
		}

		// The last line is left as long as it needs to be.
		append(LineBreaker.Item(kind: .glue, width: 0, stretch: 100_000), end: length, next: length)
		append(LineBreaker.Item(kind: .penalty, width: 0, penalty: -.infinity), end: length, next: length)
		return (items, positions)
	}

	/// How far along the paragraph, set as one long line, each character starts, plus the line's full width at the end.
	/// Measuring this way accounts for kerning and ligatures. Read from the glyph runs in one pass, because asking
	/// Core Text for each offset separately walks the whole line every time.
	private static func characterOffsets(of line: CTLine, length: Int) -> [Double] {
		var offsets = [Double](repeating: .nan, count: length + 1)

		for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
			let count = CTRunGetGlyphCount(run)
			var indices = [CFIndex](repeating: 0, count: count)
			var points = [CGPoint](repeating: .zero, count: count)
			CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
			CTRunGetPositions(run, CFRange(location: 0, length: 0), &points)

			for (index, point) in zip(indices, points) where index < length {
				if offsets[index].isNaN || point.x < offsets[index] {
					offsets[index] = point.x
				}
			}
		}

		offsets[length] = CTLineGetTypographicBounds(line, nil, nil, nil)

		// Characters drawn as part of another's glyph, like the second letter of a ligature, start where it does.
		var previous = 0.0
		for index in offsets.indices {
			if offsets[index].isNaN {
				offsets[index] = previous
			} else {
				previous = offsets[index]
			}
		}
		return offsets
	}

	private static func hyphenWidth(in text: NSAttributedString, at index: Int) -> Double {
		guard let attribute = text.attribute(NSAttributedString.Key(kCTFontAttributeName as String), at: index, effectiveRange: nil) else { return 0 }

		let font = attribute as! CTFont
		var character: UniChar = 0x2D
		var glyph = CGGlyph()
		CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)
		return CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, nil, 1)
	}

	/// Core Text's own line breaking, for paragraphs the line breaker can't fit, such as a word wider than the column.
	private static func greedyBreaks(for text: NSAttributedString, string: NSString, lineWidth: (Int) -> Double) -> [Break] {
		let typesetter = CTTypesetterCreateWithAttributedString(text)
		var breaks = [Break]()
		var start = 0

		while start < string.length {
			let count = max(CTTypesetterSuggestLineBreak(typesetter, start, lineWidth(breaks.count)), 1)
			let next = start + count
			let endsParagraph = next >= string.length || string.character(at: next - 1) == lineSeparator
			breaks.append(Break(end: next, next: next, addsHyphen: false, endsParagraph: endsParagraph))
			start = next
		}
		return breaks
	}

	// MARK: Building lines

	private func makeLine(_ text: NSAttributedString, string: NSString, start: Int, lineBreak: Break, index: Int, style: Paragraph, offset: Int, lineWidth: Double, spaceBefore: Double) -> TypesetLine {
		var end = lineBreak.end
		while end > start, [Self.space, Self.lineSeparator].contains(string.character(at: end - 1)) {
			end -= 1
		}

		let content = NSMutableAttributedString(attributedString: text.attributedSubstring(from: NSRange(location: start, length: end - start)))
		if lineBreak.addsHyphen, content.length > 0 {
			content.append(NSAttributedString(string: "-", attributes: content.attributes(at: content.length - 1, effectiveRange: nil)))
		}

		var line = CTLineCreateWithAttributedString(content)
		var lineWidthUsed = CTLineGetTypographicBounds(line, nil, nil, nil)

		if style.alignment == .justified, !lineBreak.endsParagraph {
			let spaces = (0..<content.length).filter { (content.string as NSString).character(at: $0) == Self.space }
			if !spaces.isEmpty {
				let extra = (lineWidth - lineWidthUsed) / Double(spaces.count)
				for location in spaces {
					content.addAttribute(NSAttributedString.Key(kCTKernAttributeName as String), value: extra, range: NSRange(location: location, length: 1))
				}
				line = CTLineCreateWithAttributedString(content)
				lineWidthUsed = CTLineGetTypographicBounds(line, nil, nil, nil)
			}
		}

		var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
		CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

		let indent = index == 0 ? style.firstLineIndent : style.indent
		let x = switch style.alignment {
		case .center: indent + (lineWidth - lineWidthUsed) / 2
		case .right: indent + lineWidth - lineWidthUsed
		default: indent
		}

		return TypesetLine(
			location: offset + start,
			length: end - start,
			line: line,
			x: max(x, 0),
			height: ((ascent + descent) * style.lineHeight).rounded(),
			descent: descent,
			spaceBefore: spaceBefore
		)
	}
}
