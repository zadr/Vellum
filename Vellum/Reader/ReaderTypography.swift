import CoreGraphics

/// Everything about the text that changes where page breaks fall.
nonisolated struct ReaderTypography: Equatable, Sendable {
	static let textScales = [0.8, 0.9, 1.0, 1.1, 1.2, 1.35, 1.5, 1.75, 2.0]

	/// Lines get hard to follow past this width, so wide screens get wider margins instead.
	private static let maximumLineWidth = 640.0
	private static let minimumMargin = 24.0
	private static let topMargin = 16.0
	private static let bottomMargin = 28.0

	var font: ReaderFont
	/// The body text size in points, already adjusted for Dynamic Type and the reader's text size.
	var size: Double

	/// The area text is set in on a page of the given size, in Core Text's bottom-left-origin coordinates.
	func textRect(in pageSize: CGSize) -> CGRect {
		let margin = max(Self.minimumMargin, (pageSize.width - Self.maximumLineWidth) / 2)
		return CGRect(
			x: margin,
			y: Self.bottomMargin,
			width: max(pageSize.width - margin * 2, 1),
			height: max(pageSize.height - Self.topMargin - Self.bottomMargin, 1)
		)
	}
}
