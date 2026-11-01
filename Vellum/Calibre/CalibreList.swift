import SwiftUI

struct CalibreList: View {
	@Environment(CalibreLibrary.self) private var calibre

	let sort: CalibreSort
	let searchText: String
	let showsDownloadedOnly: Bool
	let open: (CalibreBook) -> Void
	let read: (CalibreBook) -> Void
	let connect: () -> Void

	var body: some View {
		let books = visibleBooks

		List {
			if case .failed(let message) = calibre.status {
				Section {
					Label(message, systemImage: "exclamationmark.triangle")
						.foregroundStyle(.secondary)
				}
			}

			Section {
				ForEach(books) { book in
					CalibreListRow(book: book, open: open, read: read)
				}
			} footer: {
				if !books.isEmpty && searchText.isEmpty {
					Text("^[\(books.count) book](inflect: true)")
						.frame(maxWidth: .infinity)
				}
			}
		}
		.animation(.default, value: books.map(\.id))
		.overlay {
			if books.isEmpty {
				CalibreEmptyView(searchText: searchText, showsDownloadedOnly: showsDownloadedOnly, connect: connect)
			}
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
}
