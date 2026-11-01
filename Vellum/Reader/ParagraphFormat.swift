import CoreText

/// How a paragraph is set: its alignment, indents, and spacing. Attached to the paragraph's text by the
/// converter and read by the typesetter. A class, so the space after can be updated when its block closes.
nonisolated final class ParagraphFormat: @unchecked Sendable {
	var alignment = CTTextAlignment.natural
	/// Space from the left of the column to the paragraph's lines.
	var indent = 0.0
	/// Space from the paragraph's lines to the right of the column.
	var rightIndent = 0.0
	/// Extra indent for the first line only. Negative for a hanging indent, as in lists and notes.
	var firstLineIndent = 0.0
	var lineHeight = 1.0
	var spaceBefore = 0.0
	var spaceAfter = 0.0
	/// Widths of rules drawn above, below, and to the left of the paragraph. Zero for none.
	var borderTop = 0.0
	var borderBottom = 0.0
	var borderLeft = 0.0
	/// Start the paragraph on a new page.
	var breaksPageBefore = false
	/// For a table row: the table, whose columns the row's tab-separated cells line up in.
	var table: TableColumns?

	init() {}

	/// Where the first line starts, kept inside the column even when a hanging indent reaches past the indent.
	var firstLineInset: Double {
		max(indent + firstLineIndent, 0)
	}
}
