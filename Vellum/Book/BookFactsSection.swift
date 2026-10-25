import SwiftUI

/// Publication details for a book, skipping anything Open Library doesn't have.
struct BookFactsSection: View {
	let entry: Entry

	private var book: Book {
		entry.book
	}

	var body: some View {
		Section("Details") {
			if let publishDate = book.publishDate {
				LabeledContent("Published", value: publishDate)
			}

			if let publishers = book.publishers, !publishers.isEmpty {
				LabeledContent("Publisher", value: publishers.formatted(.list(type: .and)))
			}

			if let pages = book.numberOfPages {
				LabeledContent("Pages") {
					Text(pages, format: .number)
				}
			}

			if let isbn = entry.isbn {
				LabeledContent("ISBN", value: isbn.digits)
					.textSelection(.enabled)
			}

			LabeledContent("Added") {
				Text(entry.dateAdded, format: .dateTime.day().month().year())
			}

			if let subjects = book.subjects, !subjects.isEmpty {
				LabeledContent("Subjects", value: subjects.prefix(6).formatted(.list(type: .and)))
			}
		}
	}
}
