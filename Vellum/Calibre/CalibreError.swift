import Foundation

nonisolated enum CalibreError: LocalizedError {
	case notFound
	case offline
	case unavailable
	case unreadable

	var errorDescription: String? {
		switch self {
		case .notFound: "Calibre doesn’t have this book anymore."
		case .offline: "Couldn’t reach your Calibre server. Check that it’s running and you’re on the same network."
		case .unavailable: "Your Calibre server isn’t responding right now."
		case .unreadable: "Your Calibre server sent back something unexpected."
		}
	}
}
