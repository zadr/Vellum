import Foundation

/// Whether a book is read a page at a time or as one continuous scroll.
nonisolated enum ReaderMode: String, CaseIterable, Identifiable, Sendable {
	case pages
	case scroll

	var id: Self {
		self
	}

	var label: String {
		switch self {
		case .pages: "Pages"
		case .scroll: "Scroll"
		}
	}

	var systemImage: String {
		switch self {
		case .pages: "book"
		case .scroll: "scroll"
		}
	}
}
