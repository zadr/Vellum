import SwiftUI

/// The large cover and title block at the top of a book's detail screen.
struct BookHeader: View {
	@ScaledMetric(relativeTo: .title) private var coverWidth = Design.detailCoverWidth

	let entry: Entry

	var body: some View {
		VStack {
			CoverImage(book: entry.book, width: coverWidth)
				.shadow(color: .black.opacity(0.2), radius: 12, y: 6)
				.padding(.bottom)

			Text(entry.title)
				.font(.title2.bold())
				.fontDesign(.serif)

			if let subtitle = entry.book.subtitle {
				Text(subtitle)
					.font(.headline)
					.foregroundStyle(.secondary)
			}

			if let authorLine = entry.authorLine {
				Text(authorLine)
					.font(.body)
					.foregroundStyle(.secondary)
			}
		}
		.multilineTextAlignment(.center)
		.frame(maxWidth: .infinity)
		.accessibilityElement(children: .combine)
	}
}
