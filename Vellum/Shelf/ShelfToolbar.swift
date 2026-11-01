import SwiftUI

struct ShelfToolbar: ToolbarContent {
	@Binding var sort: ShelfSort

	let scan: () -> Void
	let enterISBN: () -> Void
	let newShelf: () -> Void
	let renameShelf: () -> Void
	let deleteShelf: () -> Void
	let openCalibre: () -> Void

	var body: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Menu("Shelves", systemImage: "books.vertical") {
				ShelfTitleMenu(newShelf: newShelf, renameShelf: renameShelf, deleteShelf: deleteShelf)
			}
		}

		ToolbarItem(placement: .topBarTrailing) {
			Button("Calibre Library", systemImage: "server.rack", action: openCalibre)
		}

		ToolbarItem(placement: .topBarTrailing) {
			Menu("Sort", systemImage: "arrow.up.arrow.down") {
				Picker("Sort By", selection: $sort) {
					ForEach(ShelfSort.allCases) { sort in
						Label(sort.label, systemImage: sort.systemImage)
							.tag(sort)
					}
				}
			}
		}

		ToolbarItem(placement: .bottomBar) {
			Button("Enter ISBN", systemImage: "keyboard", action: enterISBN)
		}

		ToolbarSpacer(.flexible, placement: .bottomBar)

		DefaultToolbarItem(kind: .search, placement: .bottomBar)

		ToolbarSpacer(.flexible, placement: .bottomBar)

		ToolbarItem(placement: .bottomBar) {
			Button("Scan Barcode", systemImage: "barcode.viewfinder", action: scan)
				.buttonStyle(.glassProminent)
		}
	}
}
