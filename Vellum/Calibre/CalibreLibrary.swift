import Foundation
import Observation

/// The books on the user's Calibre server, which of them are downloaded, and where the user is in each.
@Observable
final class CalibreLibrary {
	enum Status: Equatable {
		case idle
		case loading
		case failed(String)
	}

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

	init(store: CalibreStore = CalibreStore()) {
		let snapshot = store.load()

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

	/// Explains why an address can't be used, or returns `nil` if it looks fine.
	func problem(withAddress address: String) -> String? {
		CalibreClient(address: address) == nil ? "Enter your server’s address, like 192.168.1.92:8081." : nil
	}

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

	private func deleteFiles(for id: CalibreBook.ID) {
		try? FileManager.default.removeItem(at: store.bookURL(for: id))
		try? FileManager.default.removeItem(at: store.unpackedURL(for: id))
	}

	// MARK: Reading positions

	func position(for id: CalibreBook.ID) -> ReadingPosition? {
		positions[id]
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
