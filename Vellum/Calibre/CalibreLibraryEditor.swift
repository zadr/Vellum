import Foundation

enum CalibreLibraryEditor: Identifiable {
	case add
	case edit(CalibreLibrary)

	var id: String {
		switch self {
		case .add: "add"
		case .edit(let library): library.id.uuidString
		}
	}
}
