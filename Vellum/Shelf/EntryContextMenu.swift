import SwiftUI

struct EntryContextMenu: View {
	@Environment(Library.self) private var library

	let entry: Entry

	var body: some View {
		if let url = entry.book.openLibraryURL {
			ShareLink(item: url, subject: Text(entry.title), message: Text("Check out “\(entry.title)”")) {
				Label("Recommend", systemImage: "square.and.arrow.up")
			}
		}

		if let url = entry.bookshopURL {
			Link(destination: url) {
				Label("Buy on Bookshop.org", systemImage: "bag")
			}
		}

		MoveToShelfMenu(entryID: entry.id)

		Divider()

		Button("Remove", systemImage: "trash", role: .destructive, action: remove)
	}

	private func remove() {
		library.remove([entry.id])
	}
}
