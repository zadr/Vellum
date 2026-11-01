import Foundation

enum CalibreSort: String, CaseIterable, Identifiable {
	case recent
	case title
	case author

	var id: Self {
		self
	}

	var label: String {
		switch self {
		case .recent: "Recently Added"
		case .title: "Title"
		case .author: "Author"
		}
	}

	var systemImage: String {
		switch self {
		case .recent: "clock"
		case .title: "textformat"
		case .author: "person"
		}
	}

	func sorted(_ books: [CalibreBook]) -> [CalibreBook] {
		switch self {
		case .recent:
			books.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
		case .title:
			books.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
		case .author:
			books.sorted { $0.authorSortKey.localizedStandardCompare($1.authorSortKey) == .orderedAscending }
		}
	}
}
