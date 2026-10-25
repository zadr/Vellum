import Foundation

// MARK: Book -

/// An edition record from Open Library (`/isbn/{isbn}.json`).
///
/// Most fields are optional because Open Library records vary wildly in completeness.
struct Book: Codable, Hashable {
	let authors: [Author]?
	let byStatement: String?
	let covers: [Int]?
	let created: TypedValue?
	let deweyDecimalClass: [String]?
	let fullTitle: String?
	let isbn10: [String]?
	let isbn13: [String]?
	let key: String
	let languages: [Language]?
	let lastModified: TypedValue?
	let latestRevision: Int?
	let lcClassifications: [String]?
	let localId: [String]?
	let numberOfPages: Int?
	let oclcNumbers: [String]?
	let pagination: String?
	let publishCountry: String?
	let publishDate: String?
	let publishers: [String]?
	let revision: Int?
	let sourceRecords: [String]?
	let subjectPlaces: [String]?
	let subjectTimes: [String]?
	let subjects: [String]?
	let subtitle: String?
	let tableOfContents: [TableOfContent]?
	let title: String
	let works: [Work]?

	// MARK: Author -

	struct Author: Codable, Hashable {
		let key: String
	}

	// MARK: TypedValue -

	struct TypedValue: Codable, Hashable {
		let type: String
		let value: String
	}

	// MARK: Language -

	struct Language: Codable, Hashable {
		let key: String
	}

	// MARK: TableOfContent -

	struct TableOfContent: Codable, Hashable {
		let label: String?
		let level: Int?
		let pagenum: String?
		let title: String?
	}

	// MARK: Work -

	struct Work: Codable, Hashable {
		let key: String
	}
}

// MARK: -

extension Book {
	/// Decodes a book from Open Library's snake_case JSON.
	static func create(with data: Data) throws -> Book {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.self, from: data)
	}

	/// The publication year, pulled out of free-form dates like "October 1, 1988".
	var publishYear: String? {
		publishDate?.firstMatch(of: /\d{4}/).map { String($0.output) }
	}

	/// A cleaned-up "by" statement, used when author records can't be fetched.
	var cleanedByStatement: String? {
		guard let first = byStatement?.split(separator: ";").first else { return nil }

		var by = first.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
		if by.lowercased().hasPrefix("by ") {
			by = String(by.dropFirst(3))
		}

		return by.isEmpty ? nil : by
	}

	var coverURL: URL? {
		if let id = covers?.first(where: { $0 > 0 }) {
			URL(string: "https://covers.openlibrary.org/b/id/\(id)-L.jpg")
		} else {
			// `default=false` makes missing covers 404 instead of returning a blank image.
			URL(string: "https://covers.openlibrary.org/b/olid/\(key.split(separator: "/").last ?? "")-L.jpg?default=false")
		}
	}

	var openLibraryURL: URL? {
		URL(string: "https://openlibrary.org\(key)")
	}
}
