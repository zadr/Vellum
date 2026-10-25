import Foundation

enum LookupError: LocalizedError {
	case notFound
	case offline
	case unavailable
	case unreadable

	var errorDescription: String? {
		switch self {
		case .notFound: "Open Library doesn’t know this book."
		case .offline: "Couldn’t connect. Check your internet connection."
		case .unavailable: "Open Library isn’t responding right now."
		case .unreadable: "Open Library sent back something unexpected."
		}
	}
}
