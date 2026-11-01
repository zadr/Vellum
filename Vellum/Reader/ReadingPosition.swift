import Foundation

/// Where the user is in a book: a chapter, and how far through it they are.
nonisolated struct ReadingPosition: Codable, Hashable, Sendable {
	var chapter: Int
	/// From 0 at the start of the chapter to just under 1 on its last page.
	var progression: Double
}
