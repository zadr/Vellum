import CoreGraphics

/// Everything a layout depends on. When any of it changes, the book is laid out again.
struct ReaderLayoutRequest: Equatable {
	var pageSize: CGSize
	var typography: ReaderTypography
	var mode: ReaderMode
}
