import SwiftUI

/// What the Calibre list shows when it has no books to show, and why.
struct CalibreEmptyView: View {
	@Environment(CalibreLibrary.self) private var calibre

	let searchText: String
	let showsDownloadedOnly: Bool

	var body: some View {
		if !searchText.isEmpty {
			ContentUnavailableView.search
		} else if calibre.status == .loading {
			ProgressView()
		} else if showsDownloadedOnly && !calibre.books.isEmpty {
			ContentUnavailableView("No Downloaded Books", systemImage: "arrow.down.circle", description: Text("Tap a book to download it and start reading."))
		} else if case .failed(let message) = calibre.status {
			ContentUnavailableView("Can’t Reach \(calibre.name)", systemImage: "wifi.exclamationmark", description: Text(message))
		} else if calibre.status == .idle {
			ContentUnavailableView("No Books", systemImage: "books.vertical", description: Text("This Calibre library is empty."))
		}
	}
}
