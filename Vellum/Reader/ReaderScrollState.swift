/// What the scroll view reports about itself: its offset, in the terms `scrollTo(y:)` uses, and the height it shows.
struct ReaderScrollState: Equatable {
	var offset: Double
	var height: Double
}
