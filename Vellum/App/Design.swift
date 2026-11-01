import SwiftUI

/// Shared sizes and styles so every screen feels like part of the same app.
enum Design {
	/// Book covers are roughly 2:3.
	static let coverAspectRatio = 2.0 / 3.0
	static let rowCoverWidth = 48.0
	static let detailCoverWidth = 160.0
	static let coverCornerRadius = 6.0

	static let rowTextSpacing = 2.0

	static let cardCornerRadius = 20.0

	static let maximumRating = 5

	/// Body text size in the reader before Dynamic Type and the reader's own text size are applied.
	static let readerTextSize = 19.0
	/// How far each level of a book's table of contents is indented.
	static let contentsIndent = 16.0
}
