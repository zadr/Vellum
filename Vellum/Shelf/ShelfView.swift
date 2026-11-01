import SwiftUI

/// The main screen: the books on the selected shelf, with shelf switching in the title menu.
struct ShelfView: View {
	@Environment(Library.self) private var library

	@AppStorage("shelf-sort") private var sort = ShelfSort.recent
	@State private var searchText = ""
	@State private var isScanning = false
	@State private var isEnteringISBN = false
	@State private var shelfNameEditor: ShelfNameEditor?
	@State private var isConfirmingShelfDeletion = false
	@State private var isShowingCalibre = false

	var body: some View {
		let shelf = library.selectedShelf

		NavigationStack {
			ShelfList(shelf: shelf, sort: sort, searchText: searchText, scan: scan)
				.navigationTitle(shelf.name)
				.toolbarTitleMenu {
					ShelfTitleMenu(
						newShelf: newShelf,
						renameShelf: renameShelf,
						deleteShelf: confirmShelfDeletion
					)
				}
				.navigationDestination(for: Entry.ID.self, destination: BookDetailView.init)
				.searchable(text: $searchText, prompt: "Title, author, or ISBN")
				.toolbar {
					ShelfToolbar(
						sort: $sort,
						scan: scan,
						enterISBN: enterISBN,
						newShelf: newShelf,
						renameShelf: renameShelf,
						deleteShelf: confirmShelfDeletion,
						openCalibre: openCalibre
					)
				}
				.confirmationDialog("Delete “\(shelf.name)”?", isPresented: $isConfirmingShelfDeletion, titleVisibility: .visible) {
					Button("Delete Shelf", role: .destructive, action: deleteShelf)
				} message: {
					Text("^[\(shelf.entries.count) book](inflect: true) on this shelf will be removed. This can’t be undone.")
				}
		}
		.sheet(isPresented: $isScanning) {
			ScannerView()
		}
		.sheet(isPresented: $isEnteringISBN) {
			ISBNEntryView()
		}
		.sheet(item: $shelfNameEditor, content: ShelfNameSheet.init)
		.sheet(isPresented: $isShowingCalibre) {
			CalibreView()
		}
		.onChange(of: library.selectedShelfID) {
			searchText = ""
		}
	}

	private func scan() {
		isScanning = true
	}

	private func enterISBN() {
		isEnteringISBN = true
	}

	private func newShelf() {
		shelfNameEditor = .create
	}

	private func renameShelf() {
		shelfNameEditor = .rename(library.selectedShelf)
	}

	private func confirmShelfDeletion() {
		if library.selectedShelf.entries.isEmpty {
			deleteShelf()
		} else {
			isConfirmingShelfDeletion = true
		}
	}

	private func deleteShelf() {
		library.deleteShelf(library.selectedShelfID)
	}

	private func openCalibre() {
		isShowingCalibre = true
	}
}

#Preview {
	ShelfView()
		.environment(Library())
		.environment(CalibreLibrary())
}
