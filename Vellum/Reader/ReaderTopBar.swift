import SwiftUI

struct ReaderTopBar: View {
	let hasContents: Bool
	let showContents: () -> Void
	let showAppearance: () -> Void
	let close: () -> Void

	var body: some View {
		HStack {
			Button(role: .close, action: close)

			Spacer()

			Button("Contents", systemImage: "list.bullet", action: showContents)
				.disabled(!hasContents)

			Button("Appearance", systemImage: "textformat.size", action: showAppearance)
		}
		.labelStyle(.iconOnly)
		.buttonStyle(.glass)
		.buttonBorderShape(.circle)
		.controlSize(.large)
		.padding(.horizontal)
	}
}
