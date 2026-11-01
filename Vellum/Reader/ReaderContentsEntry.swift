import Foundation

/// One line of a book's table of contents.
nonisolated struct ReaderContentsEntry: Identifiable, Sendable {
	let id: Int
	let title: String
	/// How deeply nested the entry is, starting at 0.
	let level: Int
	let chapter: Int
	/// The element within the chapter the entry points to, if not its start.
	let fragment: String?
}
