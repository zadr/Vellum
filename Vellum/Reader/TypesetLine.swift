import CoreText

/// One finished line of a chapter, ready to be stacked onto a page.
nonisolated struct TypesetLine: @unchecked Sendable {
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
}
