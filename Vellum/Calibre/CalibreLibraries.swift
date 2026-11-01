import Foundation
import Observation
import OSLog

/// Every Calibre server the user has added. Each one appears as a shelf.
@Observable
final class CalibreLibraries {
	/// What's saved about each library in the list. Its catalog and books live in its own folder.
	private struct Entry: Codable {
		var id: UUID
		var name: String
		/// Relative to the Calibre folder. Empty for the library set up before there could be more than one.
		var folder: String
	}

	private(set) var libraries: [CalibreLibrary] = []

	@ObservationIgnored private var folders: [CalibreLibrary.ID: String] = [:]
	@ObservationIgnored private let directory = URL.applicationSupportDirectory.appending(path: "Calibre", directoryHint: .isDirectory)
	@ObservationIgnored private let cacheDirectory = URL.cachesDirectory.appending(path: "Calibre", directoryHint: .isDirectory)
	@ObservationIgnored private let logger = Logger(subsystem: "net.thisismyinter.Vellum", category: "CalibreLibraries")

	private var url: URL {
		directory.appending(path: "Libraries.json")
	}

	init() {
		var entries = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []

		// Before libraries were shelves there was a single one, kept directly in the Calibre folder.
		if entries.isEmpty {
			let legacy = CalibreLibrary(id: UUID(), name: "Calibre", store: store(forFolder: ""))
			if legacy.isConnected {
				entries = [Entry(id: legacy.id, name: legacy.name, folder: "")]
				libraries = [legacy]
				folders[legacy.id] = ""
				save()
				return
			}
		}

		for entry in entries {
			libraries.append(CalibreLibrary(id: entry.id, name: entry.name, store: store(forFolder: entry.folder)))
			folders[entry.id] = entry.folder
		}
	}

	func library(with id: CalibreLibrary.ID) -> CalibreLibrary? {
		libraries.first { $0.id == id }
	}

	/// Explains why a library can't be saved with these details, or returns `nil` if they're fine.
	func problem(withName name: String, address: String) -> String? {
		if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			"Give the library a name."
		} else if CalibreClient(address: address) == nil {
			"Enter the server’s address, like 192.168.1.92:8081."
		} else {
			nil
		}
	}

	@discardableResult
	func add(name: String, address: String) -> CalibreLibrary {
		let id = UUID()
		let folder = id.uuidString
		let library = CalibreLibrary(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), store: store(forFolder: folder))

		libraries.append(library)
		folders[id] = folder
		save()

		Task {
			await library.connect(to: address)
		}
		return library
	}

	func update(_ library: CalibreLibrary, name: String, address: String) {
		library.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
		save()

		Task {
			await library.connect(to: address)
		}
	}

	func remove(_ library: CalibreLibrary) {
		library.removeAll()

		if let folder = folders[library.id], !folder.isEmpty {
			try? FileManager.default.removeItem(at: directory.appending(path: folder))
			try? FileManager.default.removeItem(at: cacheDirectory.appending(path: folder))
		}

		libraries.removeAll { $0.id == library.id }
		folders[library.id] = nil
		save()
	}

	private func store(forFolder folder: String) -> CalibreStore {
		if folder.isEmpty {
			// The first library's books were unzipped straight into Caches/Books.
			return CalibreStore(directory: directory, cacheDirectory: URL.cachesDirectory)
		}
		return CalibreStore(directory: directory.appending(path: folder, directoryHint: .isDirectory), cacheDirectory: cacheDirectory.appending(path: folder, directoryHint: .isDirectory))
	}

	private func save() {
		let entries = libraries.map { Entry(id: $0.id, name: $0.name, folder: folders[$0.id] ?? "") }

		do {
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			try JSONEncoder().encode(entries).write(to: url, options: [.atomic, .completeFileProtection])
		} catch {
			logger.error("Couldn't save Calibre libraries: \(error)")
		}
	}
}
