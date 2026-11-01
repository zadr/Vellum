import SwiftUI

/// Every book on the server, matching the search and filters, as a grid of covers.
struct CalibreGrid: View {
	let title: String
	let books: [CalibreBook]
	let open: (CalibreBook) -> Void
	let read: (CalibreBook) -> Void

	var body: some View {
		VStack(alignment: .leading) {
			HStack(alignment: .firstTextBaseline) {
				Text(title)
					.font(.title2)
					.bold()

				Spacer()

				Text("^[\(books.count) book](inflect: true)")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			LazyVGrid(columns: [GridItem(.adaptive(minimum: Design.gridCoverWidth), spacing: Design.gridSpacing, alignment: .top)], spacing: Design.gridSpacing) {
				ForEach(books) { book in
					CalibreGridItem(book: book, open: open, read: read)
				}
			}
		}
		.padding(.horizontal)
	}
}
