import SwiftUI

struct MoveToShelfMenu: View {
	@Environment(Library.self) private var library

	let entryID: Entry.ID

	var body: some View {
		let currentShelfID = library.shelf(containing: entryID)?.id

		Menu("Move to Shelf", systemImage: "arrow.right.square") {
			ForEach(library.shelves) { shelf in
				Button(shelf.name) {
					library.move(entryID, to: shelf.id)
				}
				.disabled(shelf.id == currentShelfID)
			}
		}
		.disabled(library.shelves.count < 2)
	}
}
