import SwiftUI

struct CalibreToolbar: ToolbarContent {
	@Binding var sort: CalibreSort
	@Binding var showsDownloadedOnly: Bool

	let shelfMenu: ShelfTitleMenu

	var body: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Menu("Shelves", systemImage: "books.vertical") {
				shelfMenu
			}
		}

		ToolbarItem(placement: .topBarTrailing) {
			Menu("Options", systemImage: "line.3.horizontal.decrease") {
				Picker("Show", selection: $showsDownloadedOnly) {
					Label("All Books", systemImage: "books.vertical")
						.tag(false)
					Label("Downloaded", systemImage: "arrow.down.circle")
						.tag(true)
				}

				Picker("Sort By", selection: $sort) {
					ForEach(CalibreSort.allCases) { sort in
						Label(sort.label, systemImage: sort.systemImage)
							.tag(sort)
					}
				}

			}
		}
	}
}
