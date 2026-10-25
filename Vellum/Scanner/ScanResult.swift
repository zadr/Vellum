import Foundation

/// What happened to the most recent barcode the scanner saw.
struct ScanResult: Identifiable, Equatable {
	enum Outcome: Equatable {
		case queued(ISBN)
		case duplicate(ISBN, shelfName: String)
		case notABook
	}

	let id = UUID()
	let outcome: Outcome

	var isSuccess: Bool {
		if case .queued = outcome { true } else { false }
	}
}
