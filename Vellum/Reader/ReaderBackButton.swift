import SwiftUI

/// Returns to where the reader was before following a link, such as to a footnote.
struct ReaderBackButton: View {
	let goBack: () -> Void

	var body: some View {
		Button("Back", systemImage: "arrow.uturn.backward", action: goBack)
			.buttonStyle(.glass)
			.padding()
	}
}
