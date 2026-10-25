import SwiftUI

struct ShelfList: View {
	@Environment(Library.self) private var library

	let shelf: Shelf
	let sort: ShelfSort
	let searchText: String
	let scan: () -> Void

	var body: some View {
		let entries = visibleEntries
		let lookups = searchText.isEmpty ? library.lookups(for: shelf.id) : []

		List {
			if !lookups.isEmpty {
				Section {
					ForEach(lookups) { lookup in
						LookupRow(lookup: lookup)
					}
				}
			}

			Section {
				ForEach(entries) { entry in
					NavigationLink(value: entry.id) {
						EntryRow(entry: entry)
					}
					.contextMenu {
						EntryContextMenu(entry: entry)
					}
					.swipeActions {
						Button("Remove", systemImage: "trash", role: .destructive) {
							library.remove([entry.id])
						}
					}
				}
			} footer: {
				if !entries.isEmpty && searchText.isEmpty {
					Text("^[\(entries.count) book](inflect: true)")
						.frame(maxWidth: .infinity)
				}
			}
		}
		.animation(.default, value: entries.map(\.id))
		.animation(.default, value: lookups)
		.overlay {
			if entries.isEmpty && lookups.isEmpty {
				if searchText.isEmpty {
					EmptyShelfView(shelfName: shelf.name, scan: scan)
				} else {
					ContentUnavailableView.search
				}
			}
		}
	}

	private var visibleEntries: [Entry] {
		let matching = searchText.isEmpty ? shelf.entries : shelf.entries.filter { $0.matches(searchText) }
		return sort.sorted(matching)
	}
}
