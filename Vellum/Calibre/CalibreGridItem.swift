import SwiftUI

/// A book in the library grid. Tapping downloads it, or opens it if it's already downloaded.
struct CalibreGridItem: View {
	@Environment(CalibreLibrary.self) private var calibre

	let book: CalibreBook
	let open: (CalibreBook) -> Void
	let read: (CalibreBook) -> Void

	var body: some View {
		Button(action: openBook) {
			VStack(alignment: .leading) {
				CalibreCover(book: book)
				CalibreBookCaption(book: book)
			}
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.disabled(!book.hasEPUB)
		.contextMenu {
			CalibreBookContextMenu(book: book, read: readBook)
		}
		.accessibilityElement(children: .combine)
		.accessibilityHint(hint)
	}

	private var hint: String {
		if !book.hasEPUB {
			"Vellum can only open EPUB books."
		} else if calibre.isDownloaded(book.id) {
			"Opens the book."
		} else {
			"Downloads the book, then opens it."
		}
	}

	private func openBook() {
		open(book)
	}

	private func readBook() {
		read(book)
	}
}
