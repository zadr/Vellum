import SwiftUI

/// The books the user has been reading, most recent first, in a row they can scroll sideways.
struct CalibreContinueReading: View {
	let books: [CalibreBook]
	let open: (CalibreBook) -> Void
	let read: (CalibreBook) -> Void

	var body: some View {
		VStack(alignment: .leading) {
			Text("Continue Reading")
				.font(.title2)
				.bold()
				.padding(.horizontal)

			ScrollView(.horizontal) {
				LazyHStack(alignment: .top, spacing: Design.gridSpacing) {
					ForEach(books) { book in
						CalibreGridItem(book: book, open: open, read: read)
							.frame(width: Design.continueReadingCoverWidth)
					}
				}
				.padding(.horizontal)
			}
			.scrollIndicators(.hidden)
		}
	}
}
