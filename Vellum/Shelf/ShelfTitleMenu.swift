import SwiftUI

/// Shown when tapping the shelf name in the navigation bar: every shelf and Calibre library, plus ways to manage them.
struct ShelfTitleMenu: View {
	@Environment(Library.self) private var library
	@Environment(CalibreLibraries.self) private var calibreLibraries

	let newShelf: () -> Void
	let renameShelf: () -> Void
	let deleteShelf: () -> Void
	let addCalibreLibrary: () -> Void
	let editCalibreLibrary: () -> Void
	let removeCalibreLibrary: () -> Void

	var body: some View {
		@Bindable var library = library

		Picker("Shelf", selection: $library.selection) {
			ForEach(library.shelves) { shelf in
				Text(shelf.name)
					.badge(shelf.entries.count)
					.tag(ShelfSelection.shelf(shelf.id))
			}

			if !calibreLibraries.libraries.isEmpty {
				Section("Calibre") {
					ForEach(calibreLibraries.libraries) { calibreLibrary in
						Label(calibreLibrary.name, systemImage: "server.rack")
							.badge(calibreLibrary.books.count)
							.tag(ShelfSelection.calibre(calibreLibrary.id))
					}
				}
			}
		}

		Section {
			if case .calibre = library.selection {
				Button("Edit Library", systemImage: "pencil", action: editCalibreLibrary)
				Button("Remove Library", systemImage: "trash", role: .destructive, action: removeCalibreLibrary)
			} else {
				Button("Rename Shelf", systemImage: "pencil", action: renameShelf)
				Button("Delete Shelf", systemImage: "trash", role: .destructive, action: deleteShelf)
					.disabled(library.shelves.count < 2)
			}
		}

		Section {
			Button("New Shelf", systemImage: "plus", action: newShelf)
			Button("Add Calibre Library", systemImage: "server.rack", action: addCalibreLibrary)
		}
	}
}
