import SwiftUI

/// Asks for the address of the user's Calibre content server.
struct CalibreServerSheet: View {
	@Environment(CalibreLibrary.self) private var calibre
	@Environment(\.dismiss) private var dismiss

	@State private var address = ""
	@FocusState private var isFocused: Bool

	var body: some View {
		let problem = calibre.problem(withAddress: address)

		NavigationStack {
			Form {
				Section {
					TextField("Server Address", text: $address, prompt: Text("192.168.1.92:8081"))
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.submitLabel(.go)
						.focused($isFocused)
						.onSubmit(connect)
				} footer: {
					if calibre.isConnected && address.trimmingCharacters(in: .whitespaces) != calibre.serverAddress {
						Text("Switching servers removes the books you’ve downloaded from the current one.")
					} else {
						Text("Find this in Calibre under Preferences → Sharing over the net.")
					}
				}
			}
			.navigationTitle("Calibre Server")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", role: .cancel, action: cancel)
				}

				ToolbarItem(placement: .confirmationAction) {
					Button("Connect", role: .confirm, action: connect)
						.disabled(problem != nil)
				}
			}
			.onAppear {
				address = calibre.serverAddress
				isFocused = true
			}
		}
		.presentationDetents([.medium])
	}

	private func connect() {
		guard calibre.problem(withAddress: address) == nil else { return }

		let address = address
		Task {
			await calibre.connect(to: address)
		}
		dismiss()
	}

	private func cancel() {
		dismiss()
	}
}
