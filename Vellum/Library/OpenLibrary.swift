import Foundation

/// A small client for the parts of the Open Library API that Vellum uses.
struct OpenLibrary {
	private struct AuthorRecord: Decodable {
		let name: String
	}

	private struct WorkRecord: Decodable {
		struct Role: Decodable {
			let author: Book.Author
		}

		let authors: [Role]?
	}

	var session = URLSession.shared

	func book(for isbn: ISBN) async throws -> Book {
		let data = try await fetch("https://openlibrary.org/isbn/\(isbn.digits).json")

		do {
			return try Book.create(with: data)
		} catch {
			throw LookupError.unreadable
		}
	}

	/// Resolves author records to display names, skipping any that fail.
	func authorNames(for book: Book) async -> [String] {
		var keys = book.authors?.map(\.key) ?? []

		// Many editions leave authors to their work record.
		if keys.isEmpty, let work = book.works?.first {
			keys = await authorKeys(forWork: work.key)
		}

		var names = [String]()
		for key in keys {
			guard
				let data = try? await fetch("https://openlibrary.org\(key).json"),
				let record = try? JSONDecoder().decode(AuthorRecord.self, from: data)
			else { continue }

			names.append(record.name)
		}

		return names
	}

	private func authorKeys(forWork key: String) async -> [String] {
		guard
			let data = try? await fetch("https://openlibrary.org\(key).json"),
			let work = try? JSONDecoder().decode(WorkRecord.self, from: data)
		else { return [] }

		return work.authors?.map(\.author.key) ?? []
	}

	private func fetch(_ address: String) async throws -> Data {
		guard let url = URL(string: address) else { throw LookupError.unreadable }

		var request = URLRequest(url: url)
		// Open Library asks clients to identify themselves.
		request.setValue("Vellum/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: request)
		} catch {
			throw LookupError.offline
		}

		switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
		case 200..<300:
			return data
		case 404:
			throw LookupError.notFound
		default:
			throw LookupError.unavailable
		}
	}
}
