import Foundation
import Observation

/// The books on one of the user's Calibre servers, which of them are downloaded, and where the user is in each.
@Observable
final class CalibreLibrary: Identifiable {
	enum Status: Equatable {
		case idle
		case loading
		case failed(String)
	}

	let id: UUID
	/// What the library is called in the shelf list.
	var name: String
	private(set) var serverAddress: String
	private(set) var books: [CalibreBook]
	private(set) var status = Status.idle
	private(set) var downloadedIDs: Set<CalibreBook.ID>
	/// Downloads in flight, from 0 to 1.
	private(set) var downloadProgress: [CalibreBook.ID: Double] = [:]
	private(set) var downloadErrors: [CalibreBook.ID: String] = [:]

	private var positions: [CalibreBook.ID: ReadingPosition]

	@ObservationIgnored private let store: CalibreStore
	@ObservationIgnored private var downloads: [CalibreBook.ID: Task<Void, Never>] = [:]

	init(id: UUID, name: String, store: CalibreStore) {
		let snapshot = store.load()

		self.id = id
		self.name = name
		self.store = store
		serverAddress = snapshot.serverAddress
		books = snapshot.books
		positions = snapshot.positions
		downloadedIDs = Set(snapshot.books.map(\.id).filter {
			FileManager.default.fileExists(atPath: store.bookURL(for: $0).path(percentEncoded: false))
		})
	}

	var isConnected: Bool {
		client != nil
	}

	private var client: CalibreClient? {
		CalibreClient(address: serverAddress)
	}

	// MARK: Server

	func connect(to address: String) async {
		let address = address.trimmingCharacters(in: .whitespacesAndNewlines)

		if address != serverAddress {
			// Book IDs only mean something on the server they came from.
			for task in downloads.values {
				task.cancel()
			}
			for id in downloadedIDs {
				deleteFiles(for: id)
			}

			serverAddress = address
			books = []
			positions = [:]
			downloadedIDs = []
			downloadErrors = [:]
			save()
		}

		await refresh()
	}

	func refresh() async {
		guard let client, status != .loading else { return }

		status = .loading
		do {
			books = try await client.books()
			status = .idle
			save()
		} catch {
			status = .failed(error.localizedDescription)
		}
	}

	func thumbnailURL(for id: CalibreBook.ID) -> URL? {
		client?.thumbnailURL(for: id)
	}

	// MARK: Downloads

	func isDownloaded(_ id: CalibreBook.ID) -> Bool {
		downloadedIDs.contains(id)
	}

	func bookURL(for id: CalibreBook.ID) -> URL {
		store.bookURL(for: id)
	}

	func unpackedURL(for id: CalibreBook.ID) -> URL {
		store.unpackedURL(for: id)
	}

	func download(_ book: CalibreBook) {
		guard let client, book.hasEPUB, downloads[book.id] == nil, !isDownloaded(book.id) else { return }

		let id = book.id
		downloadErrors[id] = nil
		downloadProgress[id] = 0

		downloads[id] = Task {
			do {
				try await FileDownload.start(from: client.epubURL(for: id), to: store.bookURL(for: id)) { fraction in
					Task { @MainActor in
						self.updateProgress(fraction, for: id)
					}
				}

				// A fresh download replaces anything unpacked from an older copy.
				try? FileManager.default.removeItem(at: store.unpackedURL(for: id))
				downloadedIDs.insert(id)
			} catch is CancellationError {
				// Cancelled on purpose, so there's nothing to report.
			} catch {
				downloadErrors[id] = error.localizedDescription
			}

			downloadProgress[id] = nil
			downloads[id] = nil
		}
	}

	func cancelDownload(_ id: CalibreBook.ID) {
		downloads[id]?.cancel()
	}

	func removeDownload(_ id: CalibreBook.ID) {
		deleteFiles(for: id)
		downloadedIDs.remove(id)
	}

	private func updateProgress(_ fraction: Double, for id: CalibreBook.ID) {
		// Progress can arrive after the download has already finished.
		guard downloadProgress[id] != nil else { return }
		downloadProgress[id] = fraction
	}

	/// Stops downloads and deletes everything stored for this library, before it's removed.
	func removeAll() {
		for task in downloads.values {
			task.cancel()
		}
		store.removeAll()
	}

	private func deleteFiles(for id: CalibreBook.ID) {
		try? FileManager.default.removeItem(at: store.bookURL(for: id))
		try? FileManager.default.removeItem(at: store.unpackedURL(for: id))
	}

	// MARK: Reading positions

	func position(for id: CalibreBook.ID) -> ReadingPosition? {
		positions[id]
	}

	/// Downloaded books the user has been reading, most recent first.
	var recentlyRead: [CalibreBook] {
		books
			.filter { isDownloaded($0.id) && positions[$0.id]?.lastRead != nil }
			.sorted { (positions[$0.id]?.lastRead ?? .distantPast) > (positions[$1.id]?.lastRead ?? .distantPast) }
	}

	func setPosition(_ position: ReadingPosition, for id: CalibreBook.ID) {
		guard positions[id] != position else { return }

		positions[id] = position
		save()
	}

	private func save() {
		store.save(CalibreStore.Snapshot(serverAddress: serverAddress, books: books, positions: positions))
	}
}
