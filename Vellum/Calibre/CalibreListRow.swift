import SwiftUI

/// A book in the Calibre list. Tapping downloads it, or opens it if it's already downloaded.
struct CalibreListRow: View {
	@Environment(CalibreLibrary.self) private var calibre

	let book: CalibreBook
	let open: (CalibreBook) -> Void
	let read: (CalibreBook) -> Void

	var body: some View {
		Button(action: openBook) {
			CalibreBookRow(book: book)
		}
		.disabled(!book.hasEPUB)
		.contextMenu {
			CalibreBookContextMenu(book: book, read: readBook)
		}
		.swipeActions {
			if calibre.isDownloaded(book.id) {
				Button("Remove Download", systemImage: "trash", role: .destructive, action: removeDownload)
			}
		}
	}

	private func openBook() {
		open(book)
	}

	private func readBook() {
		read(book)
	}

	private func removeDownload() {
		calibre.removeDownload(book.id)
	}
}
