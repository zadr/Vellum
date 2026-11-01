import SwiftUI

/// What the Calibre list shows when it has no books to show, and why.
struct CalibreEmptyView: View {
	@Environment(CalibreLibrary.self) private var calibre

	let searchText: String
	let showsDownloadedOnly: Bool
	let connect: () -> Void

	var body: some View {
		if !calibre.isConnected {
			ContentUnavailableView {
				Label("Connect to Calibre", systemImage: "server.rack")
			} description: {
				Text("Read the books on your Calibre content server. Turn it on in Calibre under Preferences → Sharing over the net.")
			} actions: {
				Button("Connect", systemImage: "link", action: connect)
					.buttonStyle(.borderedProminent)
			}
		} else if !searchText.isEmpty {
			ContentUnavailableView.search
		} else if calibre.status == .loading {
			ProgressView()
		} else if showsDownloadedOnly && !calibre.books.isEmpty {
			ContentUnavailableView("No Downloaded Books", systemImage: "arrow.down.circle", description: Text("Tap a book to download it and start reading."))
		} else if calibre.status == .idle {
			ContentUnavailableView("No Books", systemImage: "books.vertical", description: Text("Your Calibre library is empty."))
		}
	}
}
