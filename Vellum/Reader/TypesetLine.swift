import CoreText

/// One finished line of a chapter, ready to be stacked onto a page.
nonisolated struct TypesetLine: @unchecked Sendable {
	/// A large initial letter drawn beside the first lines of a paragraph.
	struct DropCap {
		let line: CTLine
		/// How far the letter starts from the left of the text column.
		let x: Double
		/// Where the letter's baseline sits, measured down from the top of the line it's drawn with.
		let baseline: Double
	}

	/// The line's text, as a range in its chapter's text. Excludes the space or newline it broke at.
	let location: Int
	let length: Int
	let line: CTLine
	/// How far the line starts from the left of the text column, after indents and alignment.
	let x: Double
	/// The line's full height, including any extra from the line height setting.
	let height: Double
	let descent: Double
	/// Space above the line when it starts a paragraph: the previous paragraph's spacing after plus this one's before.
	let spaceBefore: Double
	var dropCap: DropCap?
	/// How many following lines must share this line's page, so a drop cap isn't split across pages.
	var keepWithNext = 0
	/// A rule drawn above the line, which starts its paragraph, or below it, which ends its paragraph.
	var borderTop = 0.0
	var borderBottom = 0.0
	/// A bar beside the line, and how far from the column's left the paragraph's text starts.
	var borderLeft = 0.0
	var paragraphIndent = 0.0
	var paragraphWidth = 0.0
	/// Filled behind the line's paragraph area. `fillsSpaceAbove` carries it up through the gap above, joining
	/// paragraphs that share a background into one block.
	var backgroundColor: CGColor?
	var fillsSpaceAbove = false
	/// For a table row: each cell's lines, with their position from the line's left and top. `line` is then empty.
	var cells: [(line: CTLine, x: Double, baseline: Double)] = []

	/// Start a new page with this line.
	var breaksPageBefore = false
	/// Keep the line on the same page as the first lines of the next paragraph, as a heading's last line does.
	var keepWithFollowing = false

	/// The gap between a rule and the text it's next to.
	static let ruleGap = 6.0

	/// Room taken above the text by a top rule.
	var spaceAboveText: Double {
		borderTop > 0 ? borderTop + Self.ruleGap : 0
	}

	/// The line's height including room for any rules, which is what the page stacks.
	var totalHeight: Double {
		height + spaceAboveText + (borderBottom > 0 ? borderBottom + Self.ruleGap : 0)
	}
}

nonisolated extension TypesetLine {
	/// The same line, claiming a wider range of the chapter's text, such as a drop cap drawn beside it.
	func including(_ range: Range<Int>) -> TypesetLine {
		var line = TypesetLine(location: range.lowerBound, length: range.count, line: line, x: x, height: height, descent: descent, spaceBefore: spaceBefore)
		line.dropCap = dropCap
		line.keepWithNext = keepWithNext
		line.borderTop = borderTop
		line.borderBottom = borderBottom
		line.borderLeft = borderLeft
		line.paragraphIndent = paragraphIndent
		line.paragraphWidth = paragraphWidth
		line.cells = cells
		line.backgroundColor = backgroundColor
		line.fillsSpaceAbove = fillsSpaceAbove
		line.breaksPageBefore = breaksPageBefore
		line.keepWithFollowing = keepWithFollowing
		return line
	}
}
