import Foundation

/// What the main screen shows: one of the user's own shelves, or the books in a Calibre library.
enum ShelfSelection: Hashable {
	case shelf(Shelf.ID)
	case calibre(CalibreLibrary.ID)
}
