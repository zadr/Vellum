import Foundation
import OSLog

/// Reads and writes the library as a single JSON file, migrating from the original UserDefaults format if needed.
struct LibraryStore {
	struct Snapshot: Codable {
		var shelves: [Shelf]
		var selectedShelfID: Shelf.ID?
		/// Set when a Calibre library, rather than a shelf, is showing.
		var selectedCalibreLibraryID: CalibreLibrary.ID?
	}

	var url = URL.documentsDirectory.appending(path: "Library.json")
	var defaults = UserDefaults.standard

	private let logger = Logger(subsystem: "net.thisismyinter.Vellum", category: "LibraryStore")

	func load() -> Snapshot {
		if let data = try? Data(contentsOf: url) {
			do {
				return try JSONDecoder().decode(Snapshot.self, from: data)
			} catch {
				// Keep the unreadable file around rather than silently overwriting someone's library.
				logger.error("Couldn't decode library: \(error)")
				try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
			}
		}

		return legacySnapshot() ?? Snapshot(shelves: [Shelf(name: "Main")])
	}

	func save(_ snapshot: Snapshot) {
		do {
			let data = try JSONEncoder().encode(snapshot)
			try data.write(to: url, options: [.atomic, .completeFileProtection])
		} catch {
			logger.error("Couldn't save library: \(error)")
		}
	}

	/// Earlier versions kept shelf names in `lists`, and each shelf's books as JSON under a key matching its name.
	/// Those keys are left in place so nothing is lost if the migration needs to be revisited.
	private func legacySnapshot() -> Snapshot? {
		guard let names = defaults.stringArray(forKey: "lists"), !names.isEmpty else { return nil }

		let shelves = names.map { name in
			let books = defaults.data(forKey: name).flatMap { try? JSONDecoder().decode([Book].self, from: $0) } ?? []

			// Books were appended in the order they were scanned, so space out the dates to keep that order.
			let entries = books.enumerated().map { index, book in
				Entry(
					isbn: (book.isbn13 ?? []).lazy.compactMap(ISBN.init).first ?? (book.isbn10 ?? []).lazy.compactMap(ISBN.init).first,
					book: book,
					authors: [],
					dateAdded: Date.now.addingTimeInterval(Double(index - books.count))
				)
			}

			return Shelf(name: name, entries: entries)
		}

		let activeName = defaults.string(forKey: "active-list")
		return Snapshot(shelves: shelves, selectedShelfID: shelves.first { $0.name == activeName }?.id)
	}
}
