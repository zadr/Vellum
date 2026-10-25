import Foundation
import Observation

/// The user's shelves and books, plus any ISBN lookups that are in flight.
@Observable
final class Library {
	enum AddResult: Equatable {
		case queued
		case alreadyQueued
		case duplicate(shelfName: String)
	}

	private(set) var shelves: [Shelf]
	private(set) var lookups: [Lookup] = []

	var selectedShelfID: Shelf.ID {
		didSet { save() }
	}

	@ObservationIgnored private let store: LibraryStore
	@ObservationIgnored private let client: OpenLibrary

	init(store: LibraryStore = LibraryStore(), client: OpenLibrary = OpenLibrary()) {
		let snapshot = store.load()
		let shelves = snapshot.shelves.isEmpty ? [Shelf(name: "Main")] : snapshot.shelves

		self.store = store
		self.client = client
		self.shelves = shelves
		selectedShelfID = shelves.first { $0.id == snapshot.selectedShelfID }?.id ?? shelves[0].id

		// Persists immediately so a library migrated from the old format is only migrated once.
		save()
	}

	var selectedShelf: Shelf {
		shelves.first { $0.id == selectedShelfID } ?? shelves[0]
	}

	func entry(with id: Entry.ID) -> Entry? {
		shelves.lazy.flatMap(\.entries).first { $0.id == id }
	}

	func shelf(containing entryID: Entry.ID) -> Shelf? {
		shelves.first { $0.entries.contains { $0.id == entryID } }
	}

	func lookups(for shelfID: Shelf.ID) -> [Lookup] {
		lookups.filter { $0.shelfID == shelfID }
	}

	// MARK: Adding books

	/// Queues an ISBN to be looked up and added to the selected shelf.
	@discardableResult
	func add(_ isbn: ISBN) -> AddResult {
		let shelf = selectedShelf

		if lookups.contains(where: { $0.isbn == isbn && $0.shelfID == shelf.id }) {
			return .alreadyQueued
		}

		if shelf.contains(isbn) {
			return .duplicate(shelfName: shelf.name)
		}

		let lookup = Lookup(isbn: isbn, shelfID: shelf.id)
		lookups.insert(lookup, at: 0)
		Task { await resolve(lookup.id) }
		return .queued
	}

	func retry(_ lookup: Lookup) {
		guard let index = lookups.firstIndex(where: { $0.id == lookup.id }) else { return }

		lookups[index].state = .loading
		Task { await resolve(lookup.id) }
	}

	func dismiss(_ lookup: Lookup) {
		lookups.removeAll { $0.id == lookup.id }
	}

	private func resolve(_ lookupID: Lookup.ID) async {
		guard let lookup = lookups.first(where: { $0.id == lookupID }) else { return }

		let book: Book
		do {
			book = try await client.book(for: lookup.isbn)
		} catch {
			if let index = lookups.firstIndex(where: { $0.id == lookupID }) {
				lookups[index].state = .failed(error.localizedDescription)
			}
			return
		}

		let authors = await client.authorNames(for: book)

		// The lookup may have been dismissed, or its shelf deleted, while the request was running.
		guard
			lookups.contains(where: { $0.id == lookupID }),
			let shelfIndex = shelves.firstIndex(where: { $0.id == lookup.shelfID })
		else { return }

		lookups.removeAll { $0.id == lookupID }

		if !shelves[shelfIndex].contains(lookup.isbn) {
			shelves[shelfIndex].entries.append(Entry(isbn: lookup.isbn, book: book, authors: authors))
			save()
		}
	}

	/// Fills in author names for books added before they were fetched.
	func backfillAuthors() async {
		let missing = shelves.flatMap(\.entries).filter(\.authors.isEmpty)

		for entry in missing {
			let names = await client.authorNames(for: entry.book)
			guard !names.isEmpty, var current = self.entry(with: entry.id) else { continue }

			current.authors = names
			update(current)
		}
	}

	// MARK: Editing books

	func update(_ entry: Entry) {
		for shelfIndex in shelves.indices {
			if let index = shelves[shelfIndex].entries.firstIndex(where: { $0.id == entry.id }) {
				shelves[shelfIndex].entries[index] = entry
				save()
				return
			}
		}
	}

	func remove(_ entryIDs: Set<Entry.ID>) {
		for index in shelves.indices {
			shelves[index].entries.removeAll { entryIDs.contains($0.id) }
		}
		save()
	}

	func move(_ entryID: Entry.ID, to shelfID: Shelf.ID) {
		guard
			let entry = entry(with: entryID),
			let destination = shelves.firstIndex(where: { $0.id == shelfID }),
			!shelves[destination].entries.contains(where: { $0.id == entryID })
		else { return }

		for index in shelves.indices {
			shelves[index].entries.removeAll { $0.id == entryID }
		}

		if let isbn = entry.isbn, shelves[destination].contains(isbn) {
			// The destination already has this book, so moving just removes the duplicate.
		} else {
			shelves[destination].entries.append(entry)
		}
		save()
	}

	// MARK: Shelves

	/// Explains why a shelf name can't be used, or returns `nil` if it's fine.
	func problem(withShelfName name: String, renaming shelfID: Shelf.ID? = nil) -> String? {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

		if trimmed.isEmpty {
			return "Give the shelf a name."
		}

		let isTaken = shelves.contains {
			$0.id != shelfID && $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
		}
		return isTaken ? "You already have a shelf called “\(trimmed)”." : nil
	}

	func createShelf(named name: String) {
		guard problem(withShelfName: name) == nil else { return }

		let shelf = Shelf(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
		shelves.append(shelf)
		selectedShelfID = shelf.id
	}

	func renameShelf(_ shelfID: Shelf.ID, to name: String) {
		guard
			problem(withShelfName: name, renaming: shelfID) == nil,
			let index = shelves.firstIndex(where: { $0.id == shelfID })
		else { return }

		shelves[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
		save()
	}

	/// Deletes a shelf and its books. The last remaining shelf can't be deleted.
	func deleteShelf(_ shelfID: Shelf.ID) {
		guard shelves.count > 1, let index = shelves.firstIndex(where: { $0.id == shelfID }) else { return }

		shelves.remove(at: index)
		lookups.removeAll { $0.shelfID == shelfID }

		if selectedShelfID == shelfID {
			selectedShelfID = shelves[min(index, shelves.count - 1)].id
		} else {
			save()
		}
	}

	private func save() {
		store.save(LibraryStore.Snapshot(shelves: shelves, selectedShelfID: selectedShelfID))
	}
}
