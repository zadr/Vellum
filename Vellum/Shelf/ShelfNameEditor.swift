import Foundation

enum ShelfNameEditor: Identifiable {
	case create
	case rename(Shelf)

	var id: String {
		switch self {
		case .create: "create"
		case .rename(let shelf): shelf.id.uuidString
		}
	}
}
