import SwiftUI

struct ReaderTopBar: View {
	let hasContents: Bool
	let showContents: () -> Void
	let close: () -> Void

	var body: some View {
		HStack {
			Button(role: .close, action: close)

			Spacer()

			Button("Contents", systemImage: "list.bullet", action: showContents)
				.disabled(!hasContents)

			ReaderAppearanceMenu()
		}
		.labelStyle(.iconOnly)
		.buttonStyle(.glass)
		.buttonBorderShape(.circle)
		.controlSize(.large)
		.padding(.horizontal)
	}
}
