import SwiftUI

struct EmptyShelfView: View {
	let shelfName: String
	let scan: () -> Void

	var body: some View {
		ContentUnavailableView {
			Label("Nothing Here Yet", systemImage: "books.vertical")
		} description: {
			Text("Scan the barcode on the back of a book to add it to “\(shelfName)”.")
		} actions: {
			Button("Scan a Book", systemImage: "barcode.viewfinder", action: scan)
				.buttonStyle(.borderedProminent)
		}
	}
}

#Preview {
	EmptyShelfView(shelfName: "Main") { }
}
