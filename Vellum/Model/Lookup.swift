import Foundation

/// An ISBN that's waiting on, or failed, an Open Library lookup.
struct Lookup: Identifiable, Hashable {
	enum State: Hashable {
		case loading
		case failed(String)
	}

	var id = UUID()
	let isbn: ISBN
	let shelfID: Shelf.ID
	var state = State.loading
}
