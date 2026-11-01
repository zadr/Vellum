import Foundation

/// A small client for the parts of the Calibre content server API that Vellum uses.
struct CalibreClient {
	private struct SearchResult: Decodable {
		let bookIDs: [Int]

		enum CodingKeys: String, CodingKey {
			case bookIDs = "book_ids"
		}
	}

	private struct Record: Decodable {
		let title: String
		let authors: [String]?
		let formats: [String]?
		let series: String?
		let seriesIndex: Double?
		let timestamp: String?

		enum CodingKeys: String, CodingKey {
			case title, authors, formats, series, timestamp
			case seriesIndex = "series_index"
		}
	}

	/// The server describes at most this many books per request.
	private static let pageSize = 200

	let server: URL
	var session = URLSession.shared

	/// Accepts what someone would type, like `192.168.1.92:8081`, as well as full URLs.
	init?(address: String) {
		var address = address.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !address.isEmpty else { return nil }

		if !address.contains("://") {
			address = "http://" + address
		}

		guard let url = URL(string: address), url.host() != nil else { return nil }
		server = url
	}

	/// Every book in the library, most recently added first.
	func books() async throws -> [CalibreBook] {
		let search = try decode(SearchResult.self, from: await fetch("ajax/search", query: ["num": "1000000", "sort": "timestamp", "sort_order": "desc"]))
		var books = [CalibreBook]()
		for start in stride(from: 0, to: search.bookIDs.count, by: Self.pageSize) {
			let ids = search.bookIDs[start..<min(start + Self.pageSize, search.bookIDs.count)]
			let data = try await fetch("ajax/books", query: ["ids": ids.map(String.init).joined(separator: ",")])
			let records = try decode([String: Record?].self, from: data)

			for id in ids {
				// Books deleted since the search come back as null.
				guard let record = records[String(id)] ?? nil else { continue }

				books.append(CalibreBook(
					id: id,
					title: record.title,
					authors: record.authors ?? [],
					formats: record.formats ?? [],
					series: record.series,
					seriesIndex: record.seriesIndex,
					dateAdded: record.timestamp.flatMap { try? Date($0, strategy: .iso8601) }
				))
			}
		}

		return books
	}

	func thumbnailURL(for id: CalibreBook.ID) -> URL {
		url("get/thumb/\(id)", query: ["sz": "300x450"])
	}

	func epubURL(for id: CalibreBook.ID) -> URL {
		url("get/epub/\(id)")
	}

	private func url(_ path: String, query: [String: String] = [:]) -> URL {
		let url = server.appending(path: path)
		return query.isEmpty ? url : url.appending(queryItems: query.map(URLQueryItem.init))
	}

	private func fetch(_ path: String, query: [String: String]) async throws -> Data {
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(from: url(path, query: query))
		} catch {
			throw CalibreError.offline
		}

		switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
		case 200..<300:
			return data
		case 404:
			throw CalibreError.notFound
		default:
			throw CalibreError.unavailable
		}
	}

	private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
		do {
			return try JSONDecoder().decode(type, from: data)
		} catch {
			throw CalibreError.unreadable
		}
	}
}
