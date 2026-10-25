import SwiftUI

/// Shown when tapping the shelf name in the navigation bar.
struct ShelfTitleMenu: View {
	@Environment(Library.self) private var library

	let newShelf: () -> Void
	let renameShelf: () -> Void
	let deleteShelf: () -> Void

	var body: some View {
		@Bindable var library = library

		Picker("Shelf", selection: $library.selectedShelfID) {
			ForEach(library.shelves) { shelf in
				Text(shelf.name)
					.badge(shelf.entries.count)
					.tag(shelf.id)
			}
		}

		Section {
			Button("New Shelf", systemImage: "plus", action: newShelf)
			Button("Rename Shelf", systemImage: "pencil", action: renameShelf)
			Button("Delete Shelf", systemImage: "trash", role: .destructive, action: deleteShelf)
				.disabled(library.shelves.count < 2)
		}
	}
}
