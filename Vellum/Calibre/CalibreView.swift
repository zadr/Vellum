import SwiftUI

/// The books on the user's Calibre server. Tapping a book downloads it, then opens it.
struct CalibreView: View {
	@Environment(CalibreLibrary.self) private var calibre

	@AppStorage("calibre-sort") private var sort = CalibreSort.recent
	@AppStorage("calibre-downloaded-only") private var showsDownloadedOnly = false
	let shelfMenu: ShelfTitleMenu

	@State private var searchText = ""
	@State private var readingBook: CalibreBook?
	/// Opened as soon as its download finishes.
	@State private var waitingBookID: CalibreBook.ID?

	var body: some View {
		let books = visibleBooks
		let recentlyRead = searchText.isEmpty ? calibre.recentlyRead : []

		ScrollView {
			VStack(alignment: .leading, spacing: Design.gridSpacing) {
				if case .failed(let message) = calibre.status {
					Label(message, systemImage: "exclamationmark.triangle")
						.foregroundStyle(.secondary)
						.padding(.horizontal)
				}

				if !recentlyRead.isEmpty {
					CalibreContinueReading(books: recentlyRead, open: open, read: read)
				}

				if !books.isEmpty {
					CalibreGrid(title: showsDownloadedOnly ? "Downloaded" : "Library", books: books, open: open, read: read)
				}
			}
			.padding(.vertical)
		}
		.overlay {
			if books.isEmpty {
				CalibreEmptyView(searchText: searchText, showsDownloadedOnly: showsDownloadedOnly)
			}
		}
		.animation(.default, value: books.map(\.id))
		.navigationTitle(calibre.name)
		.toolbarTitleMenu {
			shelfMenu
		}
		.searchable(text: $searchText, prompt: "Title, author, or series")
		.refreshable {
			await calibre.refresh()
		}
		.toolbar {
			CalibreToolbar(sort: $sort, showsDownloadedOnly: $showsDownloadedOnly, shelfMenu: shelfMenu)
		}
		.fullScreenCover(item: $readingBook, content: ReaderView.init)
		.onChange(of: calibre.downloadedIDs) {
			openWaitingBook()
		}
		.task {
			await calibre.refresh()
		}
	}

	private var visibleBooks: [CalibreBook] {
		var books = calibre.books

		if showsDownloadedOnly {
			books = books.filter { calibre.isDownloaded($0.id) }
		}

		if !searchText.isEmpty {
			books = books.filter { $0.matches(searchText) }
		}

		return sort.sorted(books)
	}

	private func open(_ book: CalibreBook) {
		if calibre.isDownloaded(book.id) {
			read(book)
		} else if calibre.downloadProgress[book.id] == nil {
			waitingBookID = book.id
			calibre.download(book)
		}
	}

	private func read(_ book: CalibreBook) {
		readingBook = book
	}

	private func openWaitingBook() {
		guard let id = waitingBookID, calibre.isDownloaded(id) else { return }

		waitingBookID = nil
		readingBook = calibre.books.first { $0.id == id }
	}
}
