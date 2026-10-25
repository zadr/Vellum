import Foundation

struct Shelf: Codable, Identifiable, Hashable {
	var id = UUID()
	var name: String
	var entries: [Entry] = []

	func contains(_ isbn: ISBN) -> Bool {
		entries.contains { $0.isbn == isbn }
	}
}
