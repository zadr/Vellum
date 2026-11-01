import SwiftUI

/// The main screen: the books on the selected shelf or Calibre library, with switching in the title menu.
struct ShelfView: View {
	@Environment(Library.self) private var library
	@Environment(CalibreLibraries.self) private var calibreLibraries

	@AppStorage("shelf-sort") private var sort = ShelfSort.recent
	@State private var searchText = ""
	@State private var isScanning = false
	@State private var isEnteringISBN = false
	@State private var shelfNameEditor: ShelfNameEditor?
	@State private var calibreLibraryEditor: CalibreLibraryEditor?
	@State private var isConfirmingShelfDeletion = false
	@State private var isConfirmingCalibreRemoval = false

	var body: some View {
		let shelf = library.selectedShelf
		let shelfMenu = ShelfTitleMenu(
			newShelf: newShelf,
			renameShelf: renameShelf,
			deleteShelf: confirmShelfDeletion,
			addCalibreLibrary: addCalibreLibrary,
			editCalibreLibrary: editCalibreLibrary,
			removeCalibreLibrary: confirmCalibreRemoval
		)

		NavigationStack {
			if let calibreLibrary = selectedCalibreLibrary {
				CalibreView(shelfMenu: shelfMenu)
					.environment(calibreLibrary)
					.id(calibreLibrary.id)
					.confirmationDialog("Remove “\(calibreLibrary.name)”?", isPresented: $isConfirmingCalibreRemoval, titleVisibility: .visible) {
						Button("Remove Library", role: .destructive, action: removeCalibreLibrary)
					} message: {
						Text("Books you’ve downloaded from it will be deleted from this device. Nothing changes on the server.")
					}
			} else {
				ShelfList(shelf: shelf, sort: sort, searchText: searchText, scan: scan)
					.navigationTitle(shelf.name)
					.toolbarTitleMenu {
						shelfMenu
					}
					.navigationDestination(for: Entry.ID.self, destination: BookDetailView.init)
					.searchable(text: $searchText, prompt: "Title, author, or ISBN")
					.toolbar {
						ShelfToolbar(sort: $sort, shelfMenu: shelfMenu, scan: scan, enterISBN: enterISBN)
					}
					.confirmationDialog("Delete “\(shelf.name)”?", isPresented: $isConfirmingShelfDeletion, titleVisibility: .visible) {
						Button("Delete Shelf", role: .destructive, action: deleteShelf)
					} message: {
						Text("^[\(shelf.entries.count) book](inflect: true) on this shelf will be removed. This can’t be undone.")
					}
			}
		}
		.sheet(isPresented: $isScanning) {
			ScannerView()
		}
		.sheet(isPresented: $isEnteringISBN) {
			ISBNEntryView()
		}
		.sheet(item: $shelfNameEditor, content: ShelfNameSheet.init)
		.sheet(item: $calibreLibraryEditor, content: CalibreLibrarySheet.init)
		.onChange(of: library.selection) {
			searchText = ""
		}
	}

	/// The Calibre library showing instead of a shelf, if there is one.
	private var selectedCalibreLibrary: CalibreLibrary? {
		guard case .calibre(let id) = library.selection else { return nil }
		return calibreLibraries.library(with: id)
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

	private func addCalibreLibrary() {
		calibreLibraryEditor = .add
	}

	private func editCalibreLibrary() {
		if let selectedCalibreLibrary {
			calibreLibraryEditor = .edit(selectedCalibreLibrary)
		}
	}

	private func confirmCalibreRemoval() {
		isConfirmingCalibreRemoval = true
	}

	private func removeCalibreLibrary() {
		guard let selectedCalibreLibrary else { return }

		library.selection = .shelf(library.selectedShelfID)
		calibreLibraries.remove(selectedCalibreLibrary)
	}
}

#Preview {
	ShelfView()
		.environment(Library())
		.environment(CalibreLibraries())
}
