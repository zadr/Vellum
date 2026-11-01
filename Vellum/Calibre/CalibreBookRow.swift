import SwiftUI

struct CalibreBookRow: View {
	@Environment(CalibreLibrary.self) private var calibre
	@ScaledMetric(relativeTo: .body) private var coverWidth = Design.rowCoverWidth

	let book: CalibreBook

	var body: some View {
		HStack {
			CoverImage(url: calibre.thumbnailURL(for: book.id), width: coverWidth)

			VStack(alignment: .leading, spacing: Design.rowTextSpacing) {
				Text(book.title)
					.font(.headline)
					.fontDesign(.serif)
					.lineLimit(3)

				if let authorLine = book.authorLine {
					Text(authorLine)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}

				CalibreBookRowFootnote(book: book)
			}
		}
		.foregroundStyle(book.hasEPUB ? .primary : .secondary)
		.accessibilityElement(children: .combine)
	}
}
