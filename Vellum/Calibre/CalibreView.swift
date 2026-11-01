import SwiftUI

/// The books on the user's Calibre server. Tapping a book downloads it, then opens it.
struct CalibreView: View {
	@Environment(CalibreLibrary.self) private var calibre
	@Environment(\.dismiss) private var dismiss

	@AppStorage("calibre-sort") private var sort = CalibreSort.recent
	@AppStorage("calibre-downloaded-only") private var showsDownloadedOnly = false
	@State private var searchText = ""
	@State private var isEditingServer = false
	@State private var readingBook: CalibreBook?
	/// Opened as soon as its download finishes.
	@State private var waitingBookID: CalibreBook.ID?

	var body: some View {
		NavigationStack {
			CalibreList(
				sort: sort,
				searchText: searchText,
				showsDownloadedOnly: showsDownloadedOnly,
				open: open,
				read: read,
				connect: editServer
			)
			.navigationTitle("Calibre")
			.searchable(text: $searchText, prompt: "Title, author, or series")
			.refreshable {
				await calibre.refresh()
			}
			.toolbar {
				CalibreToolbar(
					sort: $sort,
					showsDownloadedOnly: $showsDownloadedOnly,
					done: close,
					editServer: editServer
				)
			}
		}
		.sheet(isPresented: $isEditingServer) {
			CalibreServerSheet()
		}
		.fullScreenCover(item: $readingBook, content: ReaderView.init)
		.onChange(of: calibre.downloadedIDs) {
			if let id = waitingBookID, calibre.isDownloaded(id) {
				waitingBookID = nil
				readingBook = calibre.books.first { $0.id == id }
			}
		}
		.task {
			await calibre.refresh()
		}
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

	private func editServer() {
		isEditingServer = true
	}

	private func close() {
		dismiss()
	}
}

#Preview {
	CalibreView()
		.environment(CalibreLibrary())
}
