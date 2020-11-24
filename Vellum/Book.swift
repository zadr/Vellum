import Foundation

// MARK: Book -

public struct Book: Codable {
	public let authors: [Author]?
	public let byStatement: String?
	public let created: Created
//	public let description: Description? // sometimes a String instead of a Dictionary?
	public let deweyDecimalClass: [String]?
	public let fullTitle: String?
	public let isbn10: [String]?
	public let isbn13: [String]?
	public let key: String
	public let languages: [Language]?
	public let lastModified: LastModified
	public let latestRevision: Int
	public let lcClassifications: [String]?
	public let localId: [String]?
//	public let notes: Note? // sometimes a String instead of a Dictionary?zsDF
	public let numberOfPages: Int?
	public let oclcNumbers: [String]?
	public let pagination: String?
	public let publishCountry: String?
	public let publishDate: String
	public let revision: Int
	public let sourceRecords: [String]?
	public let subjectPlaces: [String]?
	public let subjectTimes: [String]?
	public let subjects: [String]?
	public let subtitle: String?
	public let tableOfContents: [TableOfContent]?
	public let title: String
	public let works: [Work]

	// MARK: Author -

	public struct Author: Codable {
		public let key: String
	}

	// MARK: Created -

	public struct Created: Codable {
		public let type: String
		public let value: String
	}

	// MARK: Description -

	public struct Description: Codable {
		public let type: String
		public let value: String
	}

	// MARK: Language -

	public struct Language: Codable {
		public let key: String
	}

	// MARK: LastModified -

	public struct LastModified: Codable {
		public let type: String
		public let value: String
	}

	// MARK: Note -

	public struct Note: Codable {
		public let type: String
		public let value: String
	}

	// MARK: TableOfContent -

	public struct TableOfContent: Codable {
		public let label: String
		public let level: Int
		public let pagenum: String
		public let title: String?
	}

	// MARK: Work -

	public struct Work: Codable {
		public let key: String
	}
}

// MARK: -

public extension Book.LastModified {
	static func create(with data: Data) throws -> Book.LastModified  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.LastModified.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.LastModified]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.LastModified].self, from: data)
	}
}

// MARK: -

public extension Book.Description {
	static func create(with data: Data) throws -> Book.Description  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.Description.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.Description]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.Description].self, from: data)
	}
}

// MARK: -

public extension Book.Author {
	static func create(with data: Data) throws -> Book.Author  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.Author.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.Author]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.Author].self, from: data)
	}
}

// MARK: -

public extension Book {
	static func create(with data: Data) throws -> Book  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.self, from: data)
	}

	static func create(with data: Data) throws -> [Book]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book].self, from: data)
	}
}

// MARK: -

public extension Book.Language {
	static func create(with data: Data) throws -> Book.Language  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.Language.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.Language]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.Language].self, from: data)
	}
}

// MARK: -

public extension Book.Work {
	static func create(with data: Data) throws -> Book.Work  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.Work.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.Work]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.Work].self, from: data)
	}
}

// MARK: -

public extension Book.Note {
	static func create(with data: Data) throws -> Book.Note  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.Note.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.Note]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.Note].self, from: data)
	}
}

// MARK: -

public extension Book.Created {
	static func create(with data: Data) throws -> Book.Created  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.Created.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.Created]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.Created].self, from: data)
	}
}

// MARK: -

public extension Book.TableOfContent {
	static func create(with data: Data) throws -> Book.TableOfContent  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(Book.TableOfContent.self, from: data)
	}

	static func create(with data: Data) throws -> [Book.TableOfContent]  {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode([Book.TableOfContent].self, from: data)
	}
}


public protocol JSONRepresentable {}
extension Int : JSONRepresentable {}
extension Double : JSONRepresentable {}
extension Float : JSONRepresentable {}
extension Bool : JSONRepresentable {}
extension Sequence where Element : JSONRepresentable {}
extension Dictionary where Key : JSONRepresentable, Value : JSONRepresentable {}

