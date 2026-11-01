import SwiftUI

struct CalibreBookContextMenu: View {
	@Environment(CalibreLibrary.self) private var calibre

	let book: CalibreBook
	let read: () -> Void

	var body: some View {
		if calibre.isDownloaded(book.id) {
			Button("Read", systemImage: "book", action: read)

			Divider()

			Button("Remove Download", systemImage: "trash", role: .destructive, action: removeDownload)
		} else if calibre.downloadProgress[book.id] != nil {
			Button("Cancel Download", systemImage: "xmark", action: cancelDownload)
		} else if book.hasEPUB {
			Button("Download", systemImage: "arrow.down.circle", action: download)
		}
	}

	private func download() {
		calibre.download(book)
	}

	private func cancelDownload() {
		calibre.cancelDownload(book.id)
	}

	private func removeDownload() {
		calibre.removeDownload(book.id)
	}
}
