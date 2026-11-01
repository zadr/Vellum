import CoreText

/// One finished line of a chapter, ready to be stacked onto a page.
nonisolated struct TypesetLine: @unchecked Sendable {
	/// A large initial letter drawn beside the first lines of a paragraph.
	struct DropCap {
		let line: CTLine
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
}

nonisolated extension TypesetLine {
	/// The same line, claiming a wider range of the chapter's text, such as a drop cap drawn beside it.
	func including(_ range: Range<Int>) -> TypesetLine {
		var line = TypesetLine(location: range.lowerBound, length: range.count, line: line, x: x, height: height, descent: descent, spaceBefore: spaceBefore)
		line.dropCap = dropCap
		line.keepWithNext = keepWithNext
		return line
	}
}
