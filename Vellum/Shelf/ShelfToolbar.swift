import SwiftUI

struct ShelfToolbar: ToolbarContent {
	@Binding var sort: ShelfSort

	let shelfMenu: ShelfTitleMenu
	let scan: () -> Void
	let enterISBN: () -> Void

	var body: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Menu("Shelves", systemImage: "books.vertical") {
				shelfMenu
			}
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
