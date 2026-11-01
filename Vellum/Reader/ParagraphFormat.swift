import CoreText

/// How a paragraph is set: its alignment, indents, and spacing. Attached to the paragraph's text by the
/// converter and read by the typesetter. A class, so the space after can be updated when its block closes.
nonisolated final class ParagraphFormat: @unchecked Sendable {
	var alignment = CTTextAlignment.natural
	/// Space from the left of the column to the paragraph's lines.
	var indent = 0.0
	/// Extra indent for the first line only. Negative for a hanging indent, as in lists and notes.
	var firstLineIndent = 0.0
	var lineHeight = 1.0
	var spaceBefore = 0.0
	var spaceAfter = 0.0

	init() {}

	/// Where the first line starts, kept inside the column even when a hanging indent reaches past the indent.
	var firstLineInset: Double {
		max(indent + firstLineIndent, 0)
	}
}
