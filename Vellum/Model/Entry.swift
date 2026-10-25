import Foundation

/// A book on one of the user's shelves, along with everything the user has added to it.
struct Entry: Codable, Identifiable, Hashable {
	var id = UUID()
	var isbn: ISBN?
	var book: Book
	var authors: [String]
	var dateAdded = Date.now
	/// 0 means unrated, otherwise 1–5 stars.
	var rating = 0
	var notes = ""

	var title: String {
		book.title
	}

	var authorLine: String? {
		authors.isEmpty ? book.cleanedByStatement : authors.formatted(.list(type: .and))
	}

	/// Used for sorting by author; falls back to the title so unattributed books still sort sensibly.
	var authorSortKey: String {
		authors.first ?? book.cleanedByStatement ?? title
	}

	var bookshopURL: URL? {
		let query = isbn?.digits ?? title
		var components = URLComponents(string: "https://bookshop.org/search")
		components?.queryItems = [URLQueryItem(name: "keywords", value: query)]
		return components?.url
	}

	func matches(_ search: String) -> Bool {
		title.localizedStandardContains(search)
			|| (authorLine?.localizedStandardContains(search) ?? false)
			|| (isbn?.digits.contains(search) ?? false)
	}
}
