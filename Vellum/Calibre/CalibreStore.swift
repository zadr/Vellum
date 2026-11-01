import Foundation
import OSLog

/// Reads and writes one Calibre library's catalog and reading positions, and decides where its downloaded books live.
struct CalibreStore {
	struct Snapshot: Codable {
		var serverAddress = ""
		var books: [CalibreBook] = []
		var positions: [CalibreBook.ID: ReadingPosition] = [:]
	}

	/// Where the catalog and downloaded books are kept.
	var directory: URL
	/// Where books are unzipped for reading. The system may clear this; it's rebuilt when needed.
	var cacheDirectory: URL

	private let logger = Logger(subsystem: "net.thisismyinter.Vellum", category: "CalibreStore")

	private var url: URL {
		directory.appending(path: "Calibre.json")
	}

	func load() -> Snapshot {
		guard let data = try? Data(contentsOf: url) else { return Snapshot() }

		do {
			return try JSONDecoder().decode(Snapshot.self, from: data)
		} catch {
			// The catalog can be fetched again, but keep the file so reading positions aren't lost for good.
			logger.error("Couldn't decode Calibre data: \(error)")
			try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
			return Snapshot()
		}
	}

	func save(_ snapshot: Snapshot) {
		do {
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			let data = try JSONEncoder().encode(snapshot)
			try data.write(to: url, options: [.atomic, .completeFileProtection])
		} catch {
			logger.error("Couldn't save Calibre data: \(error)")
		}
	}

	/// Where a downloaded EPUB is kept until the user removes it.
	func bookURL(for id: CalibreBook.ID) -> URL {
		directory.appending(path: "Books/\(id).epub")
	}

	func unpackedURL(for id: CalibreBook.ID) -> URL {
		cacheDirectory.appending(path: "Books/\(id)", directoryHint: .isDirectory)
	}

	/// Deletes the catalog, reading positions, and every downloaded book.
	func removeAll() {
		let fileManager = FileManager.default
		try? fileManager.removeItem(at: url)
		try? fileManager.removeItem(at: directory.appending(path: "Books"))
		try? fileManager.removeItem(at: cacheDirectory.appending(path: "Books"))
	}
}
