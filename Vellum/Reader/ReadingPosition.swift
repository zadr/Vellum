import Foundation

/// Where the user is in a book.
nonisolated struct ReadingPosition: Codable, Hashable, Sendable {
	var chapter: Int
	/// From 0 at the start of the chapter to just under 1 on its last page. Used when `offset` is missing.
	var progression: Double
	/// How much of the whole book is read, from 0 to 1. Missing for positions saved before this was tracked.
	var fractionRead: Double?
	var lastRead: Date?
	/// The first character on screen, counted from the start of the chapter's text. The text doesn't change
	/// with fonts or page size, so this finds the same spot under any settings.
	var offset: Int?
}
