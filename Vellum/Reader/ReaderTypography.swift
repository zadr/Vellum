import CoreGraphics

/// Everything about the text that changes where lines and pages break.
nonisolated struct ReaderTypography: Equatable, Sendable {
	static let textScales = 0.8...2.0
	static let lineHeights = 1.0...2.0
	/// Measured in multiples of the text size.
	static let paragraphSpacings = 0.0...1.5
	/// The narrowest column allowed, in points. The widest is whatever fits the screen.
	static let minimumColumnWidth = 260.0

	static let defaultTextScale = 1.0
	static let defaultLineHeight = 1.3
	static let defaultParagraphSpacing = 0.6
	/// Lines much longer than this get hard to follow, so wide screens get wider margins by default.
	static let defaultColumnWidth = 640.0

	private static let minimumMargin = 20.0
	private static let topMargin = 16.0
	private static let bottomMargin = 28.0

	var font: ReaderFont
	/// The body text size in points, already adjusted for Dynamic Type and the reader's text size.
	var size: Double
	/// A multiple of the font's natural line height. Used when the book's line heights are overridden, or it sets none.
	var lineHeight = Self.defaultLineHeight
	/// Space after each paragraph, as a multiple of the text size. Used when the book's spacing is overridden.
	var paragraphSpacing = Self.defaultParagraphSpacing
	/// The widest a line of text may be, in points. Narrower screens use all the room they have.
	var columnWidth = Self.defaultColumnWidth
	/// Which parts of the book's own styling to follow.
	var styles = ReaderStyleSettings()

	/// The widest column that fits on a page of this width.
	static func maximumColumnWidth(forPageWidth width: Double) -> Double {
		max(width - minimumMargin * 2, minimumColumnWidth)
	}

	/// The area text is set in on a page, measured from the page's top left.
	func textRect(in pageSize: CGSize, mode: ReaderMode) -> CGRect {
		let width = min(columnWidth, Self.maximumColumnWidth(forPageWidth: pageSize.width))
		let x = max((pageSize.width - width) / 2, 0)

		switch mode {
		case .pages:
			return CGRect(x: x, y: Self.topMargin, width: width, height: max(pageSize.height - Self.topMargin - Self.bottomMargin, 1))
		case .scroll:
			// Scrolling text is cut into screen-sized pieces that sit edge to edge, so there are no vertical margins.
			return CGRect(x: x, y: 0, width: width, height: max(pageSize.height, 1))
		}
	}
}
