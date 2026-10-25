import SwiftUI

struct BookDetailContent: View {
	@Environment(Library.self) private var library
	@Environment(\.dismiss) private var dismiss

	let entry: Entry

	@State private var rating: Int
	@State private var notes: String
	@State private var isConfirmingRemoval = false

	init(entry: Entry) {
		self.entry = entry
		_rating = State(initialValue: entry.rating)
		_notes = State(initialValue: entry.notes)
	}

	var body: some View {
		Form {
			Section {
				BookHeader(entry: entry)
			}
			.listRowBackground(Color.clear)

			Section("Your Rating") {
				RatingView(rating: $rating)
					.frame(maxWidth: .infinity)
			}

			Section("Notes") {
				TextField("What did you think?", text: $notes, axis: .vertical)
					.lineLimit(3...)
			}

			BookFactsSection(entry: entry)

			Section {
				if let url = entry.book.openLibraryURL {
					ShareLink(item: url, subject: Text(entry.title), message: Text("Check out “\(entry.title)”")) {
						Label("Recommend", systemImage: "square.and.arrow.up")
					}

					Link(destination: url) {
						Label("View on Open Library", systemImage: "globe")
					}
				}

				if let url = entry.bookshopURL {
					Link(destination: url) {
						Label("Buy on Bookshop.org", systemImage: "bag")
					}
				}

				MoveToShelfMenu(entryID: entry.id)
			}

			Section {
				Button("Remove from Shelf", systemImage: "trash", role: .destructive, action: confirmRemoval)
					.confirmationDialog("Remove “\(entry.title)”?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
						Button("Remove", role: .destructive, action: remove)
					} message: {
						Text("Your rating and notes for this book will be deleted too.")
					}
			}
		}
		.navigationTitle(entry.title)
		.navigationBarTitleDisplayMode(.inline)
		.scrollDismissesKeyboard(.interactively)
		.onChange(of: rating, save)
		.onChange(of: notes, save)
	}

	private func save() {
		guard var current = library.entry(with: entry.id) else { return }

		current.rating = rating
		current.notes = notes
		library.update(current)
	}

	private func confirmRemoval() {
		isConfirmingRemoval = true
	}

	private func remove() {
		library.remove([entry.id])
		dismiss()
	}
}
