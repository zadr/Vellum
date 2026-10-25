import SwiftUI

struct EntryRow: View {
	@ScaledMetric(relativeTo: .body) private var coverWidth = Design.rowCoverWidth

	let entry: Entry

	var body: some View {
		HStack {
			CoverImage(book: entry.book, width: coverWidth)

			VStack(alignment: .leading, spacing: Design.rowTextSpacing) {
				Text(entry.title)
					.font(.headline)
					.fontDesign(.serif)
					.lineLimit(3)

				if let authorLine = entry.authorLine {
					Text(authorLine)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}

				EntryRowFootnote(entry: entry)
			}
		}
		.accessibilityElement(children: .combine)
	}
}

#Preview {
	List {
		EntryRow(entry: .preview)
	}
}
