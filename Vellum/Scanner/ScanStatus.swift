import Foundation

/// The content of the scanner's status card.
struct ScanStatus: Equatable {
	var entry: Entry?
	var systemImage: String
	var title: String
	var detail: String?
	var isWarning = false
}
