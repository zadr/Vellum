import SwiftUI

struct BookDetailView: View {
	@Environment(Library.self) private var library

	let entryID: Entry.ID

	var body: some View {
		if let entry = library.entry(with: entryID) {
			BookDetailContent(entry: entry)
		} else {
			ContentUnavailableView("Book Removed", systemImage: "book.closed", description: Text("This book is no longer on any of your shelves."))
		}
	}
}

#Preview {
	NavigationStack {
		BookDetailContent(entry: .preview)
	}
	.environment(Library())
}
