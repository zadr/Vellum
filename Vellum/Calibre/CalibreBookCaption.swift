import SwiftUI

/// The title and author under a cover, plus what state the book is in.
struct CalibreBookCaption: View {
	let book: CalibreBook

	var body: some View {
		VStack(alignment: .leading, spacing: Design.rowTextSpacing) {
			Text(book.title)
				.font(.subheadline)
				.fontDesign(.serif)
				.lineLimit(2)

			if let authorLine = book.authorLine {
				Text(authorLine)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			CalibreBookStatus(book: book)
				.font(.caption)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
