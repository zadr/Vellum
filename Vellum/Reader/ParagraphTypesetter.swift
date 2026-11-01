import CoreText
import Foundation

/// Sets a chapter's text into lines: chooses breaks with `LineBreaker`, hyphenating where it helps,
/// then builds each line with Core Text. Justified lines are filled out by widening the spaces between words only.
nonisolated struct ParagraphTypesetter {
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
		var previousBackground: CGColor?
		var start = 0

		while start < string.length {
			let newline = string.range(of: "\n", range: NSRange(location: start, length: string.length - start))
			let end = newline.location == NSNotFound ? string.length : newline.location

			if end > start {
				let format = text.attribute(ChapterConverter.formatAttribute, at: start, effectiveRange: nil) as? ParagraphFormat ?? ParagraphFormat()
				let range = NSRange(location: start, length: end - start)
				// Like CSS margins, the space between paragraphs is the larger of the two, not their sum.
				var paragraphLines = setParagraph(text.attributedSubstring(from: range), style: format, offset: start, spaceBefore: max(previousSpaceAfter, format.spaceBefore))
				if let background = format.backgroundColor {
					for index in paragraphLines.indices {
						paragraphLines[index].backgroundColor = background
						// Lines within a paragraph always join; the first joins the paragraph above if it shares the block.
						paragraphLines[index].fillsSpaceAbove = index > 0 || previousBackground === background
					}
				}
				lines += paragraphLines
				previousSpaceAfter = format.spaceAfter
				previousBackground = format.backgroundColor
			}

			start = end + 1
		}

		return lines
	}

	// MARK: Paragraphs

	private func setParagraph(_ paragraph: NSAttributedString, style: ParagraphFormat, offset paragraphOffset: Int, spaceBefore: Double) -> [TypesetLine] {
		if let table = style.table {
			var row = tableRow(paragraph, table: table, style: style, offset: paragraphOffset, spaceBefore: spaceBefore)
			row.breaksPageBefore = style.breaksPageBefore
			return [row]
		}

		// A drop cap is taken out of the text and drawn beside the first lines, which are shortened to make room.
		let dropCap = Self.dropCap(in: paragraph, lineHeight: style.lineHeight)
		let capLength = dropCap?.length ?? 0
		let text = capLength > 0 ? paragraph.attributedSubstring(from: NSRange(location: capLength, length: paragraph.length - capLength)) : paragraph
		let offset = paragraphOffset + capLength

		let string = text.string as NSString
		let offsets = Self.characterOffsets(of: CTLineCreateWithAttributedString(text), length: string.length)
		let isJustified = style.alignment == .justified

		func inset(_ line: Int) -> Double {
			if let dropCap, line < dropCap.lines {
				return style.indent + dropCap.width
			}
			return line == 0 ? style.firstLineInset : style.indent
		}

		func lineWidth(_ line: Int) -> Double {
			max(width - inset(line) - style.rightIndent, 1)
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
			let index = lines.count
			lines.append(makeLine(text, string: string, start: start, lineBreak: lineBreak, index: index, style: style, offset: offset, inset: inset(index), lineWidth: lineWidth(index), spaceBefore: lines.isEmpty ? spaceBefore : 0))
			start = lineBreak.next
		}

		// The gap a rule needs is added to the space around the paragraph, so it never touches the text.
		for index in lines.indices {
			lines[index].borderLeft = style.borderLeft
			lines[index].paragraphIndent = style.indent
			lines[index].paragraphWidth = width - style.indent - style.rightIndent
		}
		if style.borderTop > 0, !lines.isEmpty {
			lines[0].borderTop = style.borderTop
		}
		if style.breaksPageBefore, !lines.isEmpty {
			lines[0].breaksPageBefore = true
		}

		// Widows and orphans: a page may only break inside the paragraph where it leaves enough lines on each side.
		// The paragraph's first lines are kept together, as are its last lines; short paragraphs stay whole.
		if !lines.isEmpty {
			let orphans = max(style.orphans, 1), widows = max(style.widows, 1)
			if lines.count < orphans + widows {
				lines[0].keepWithNext = max(lines[0].keepWithNext, lines.count - 1)
			} else {
				lines[0].keepWithNext = max(lines[0].keepWithNext, orphans - 1)
				let lastStart = lines.count - widows
				lines[lastStart].keepWithNext = max(lines[lastStart].keepWithNext, widows - 1)
			}
			// A heading takes the start of whatever follows it onto its page.
			if style.keepWithNext {
				lines[lines.count - 1].keepWithFollowing = true
			}
		}
		if style.borderBottom > 0, !lines.isEmpty {
			lines[lines.count - 1].borderBottom = style.borderBottom
		}

		if let dropCap, !lines.isEmpty {
			// The letter's baseline lines up with the baseline of the last line it spans.
			let spanned = lines.prefix(dropCap.lines)
			let last = spanned[spanned.endIndex - 1]
			let baseline = spanned.dropLast().reduce(0) { $0 + $1.height } + last.height - last.descent

			lines[0].dropCap = TypesetLine.DropCap(line: dropCap.line, x: style.indent, baseline: baseline)
			lines[0].keepWithNext = spanned.count - 1
			lines[0] = lines[0].including(paragraphOffset..<(lines[0].location + lines[0].length))
		}
		return lines
	}

	/// A table row set as one tall line: each cell is broken into lines within its column, and the row is as tall
	/// as its tallest cell.
	private func tableRow(_ row: NSAttributedString, table: TableColumns, style: ParagraphFormat, offset: Int, spaceBefore: Double) -> TypesetLine {
		let available = width - style.indent - style.rightIndent
		let columns = table.columns(width: available, gap: 12)
		let string = row.string as NSString

		var cellRanges = [NSRange]()
		var start = 0
		for index in 0...string.length where index == string.length || string.character(at: index) == 0x09 {
			cellRanges.append(NSRange(location: start, length: index - start))
			start = index + 1
		}

		var pieces = [(line: CTLine, x: Double, baseline: Double)]()
		var rowHeight = 0.0
		var lastDescent = 0.0
		for (index, range) in cellRanges.enumerated() where index < columns.count && range.length > 0 {
			let cell = row.attributedSubstring(from: range)
			let typesetter = CTTypesetterCreateWithAttributedString(cell)
			var y = 0.0
			var location = 0
			let cellString = cell.string as NSString
			while location < cell.length {
				var count = max(CTTypesetterSuggestLineBreak(typesetter, location, columns[index].width), 1)
				// Line breaks within the cell end the line there, and aren't drawn.
				let lineBreak = cellString.range(of: "\u{2028}", range: NSRange(location: location, length: count))
				var drawn = count
				if lineBreak.location != NSNotFound {
					count = lineBreak.location - location + 1
					drawn = count - 1
				}
				let line = CTTypesetterCreateLine(typesetter, CFRange(location: location, length: drawn))
				var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
				CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
				let lineHeight = ((ascent + descent) * style.lineHeight).rounded()
				pieces.append((line, columns[index].x, y + lineHeight - descent))
				y += lineHeight
				lastDescent = descent
				location += count
			}
			rowHeight = max(rowHeight, y)
		}

		var typeset = TypesetLine(location: offset, length: row.length, line: CTLineCreateWithAttributedString(NSAttributedString()), x: style.indent, height: max(rowHeight, 1), descent: lastDescent, spaceBefore: spaceBefore)
		typeset.paragraphIndent = style.indent
		typeset.paragraphWidth = available
		typeset.cells = pieces
		return typeset
	}

	/// A paragraph's drop cap, set at the size that makes its capital as tall as the lines it spans.
	private static func dropCap(in paragraph: NSAttributedString, lineHeight: Double) -> (line: CTLine, length: Int, lines: Int, width: Double)? {
		var range = NSRange()
		guard
			paragraph.length > 1,
			let lines = paragraph.attribute(ChapterConverter.dropCapAttribute, at: 0, effectiveRange: &range) as? Int,
			range.length < paragraph.length,
			let attribute = paragraph.attribute(NSAttributedString.Key(kCTFontAttributeName as String), at: range.length, effectiveRange: nil)
		else { return nil }

		// Measured against the text after the cap, which is what the cap has to line up with.
		let bodyFont = attribute as! CTFont
		let bodySize = CTFontGetSize(bodyFont)
		let lineAdvance = ((CTFontGetAscent(bodyFont) + CTFontGetDescent(bodyFont)) * lineHeight).rounded()
		let capHeightRatio = CTFontGetCapHeight(bodyFont) / bodySize
		guard capHeightRatio > 0 else { return nil }

		let capHeight = Double(lines - 1) * lineAdvance + CTFontGetCapHeight(bodyFont)
		let capFont = CTFontCreateCopyWithAttributes(bodyFont, capHeight / capHeightRatio, nil, nil)

		let letters = NSMutableAttributedString(attributedString: paragraph.attributedSubstring(from: range))
		let fullRange = NSRange(location: 0, length: letters.length)
		letters.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: capFont, range: fullRange)
		letters.removeAttribute(NSAttributedString.Key(kCTSuperscriptAttributeName as String), range: fullRange)

		let line = CTLineCreateWithAttributedString(letters)
		let width = CTLineGetTypographicBounds(line, nil, nil, nil) + bodySize * 0.3
		return (line, range.length, lines, width.rounded(.up))
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

	private func makeLine(_ text: NSAttributedString, string: NSString, start: Int, lineBreak: Break, index: Int, style: ParagraphFormat, offset: Int, inset: Double, lineWidth: Double, spaceBefore: Double) -> TypesetLine {
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

		let x = switch style.alignment {
		case .center: inset + (lineWidth - lineWidthUsed) / 2
		case .right: inset + lineWidth - lineWidthUsed
		default: inset
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
