import Foundation

enum ShelfSort: String, CaseIterable, Identifiable {
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

	func sorted(_ entries: [Entry]) -> [Entry] {
		switch self {
		case .recent:
			entries.sorted { $0.dateAdded > $1.dateAdded }
		case .title:
			entries.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
		case .author:
			entries.sorted { $0.authorSortKey.localizedStandardCompare($1.authorSortKey) == .orderedAscending }
		}
	}
}
