import SwiftUI

/// The publication year and rating shown under a book's author.
struct EntryRowFootnote: View {
	let entry: Entry

	var body: some View {
		if entry.book.publishYear != nil || entry.rating > 0 {
			HStack {
				if let year = entry.book.publishYear {
					Text(year)
						.foregroundStyle(.secondary)
				}

				if entry.rating > 0 {
					Text(String(repeating: "★", count: entry.rating))
						.foregroundStyle(.yellow)
						.accessibilityLabel("\(entry.rating) of \(Design.maximumRating) stars")
				}
			}
			.font(.footnote)
		}
	}
}
