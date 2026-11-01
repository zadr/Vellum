import SwiftUI

/// Adds a Calibre library as a shelf, or changes one's name or server.
struct CalibreLibrarySheet: View {
	@Environment(Library.self) private var library
	@Environment(CalibreLibraries.self) private var calibreLibraries
	@Environment(\.dismiss) private var dismiss

	let editor: CalibreLibraryEditor

	@State private var name: String
	@State private var address: String
	@FocusState private var focusedField: Field?

	private enum Field {
		case name
		case address
	}

	init(editor: CalibreLibraryEditor) {
		self.editor = editor

		if case .edit(let library) = editor {
			_name = State(initialValue: library.name)
			_address = State(initialValue: library.serverAddress)
		} else {
			_name = State(initialValue: "Calibre")
			_address = State(initialValue: "")
		}
	}

	var body: some View {
		let problem = calibreLibraries.problem(withName: name, address: address)

		NavigationStack {
			Form {
				Section {
					TextField("Name", text: $name, prompt: Text("Calibre"))
						.textInputAutocapitalization(.words)
						.submitLabel(.next)
						.focused($focusedField, equals: .name)
						.onSubmit(focusAddress)

					TextField("Server Address", text: $address, prompt: Text("192.168.1.92:8081"))
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.submitLabel(.done)
						.focused($focusedField, equals: .address)
						.onSubmit(save)
				} footer: {
					Text(footer)
				}
			}
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", role: .cancel, action: cancel)
				}

				ToolbarItem(placement: .confirmationAction) {
					Button(confirmLabel, role: .confirm, action: save)
						.disabled(problem != nil)
				}
			}
			.onAppear(perform: focusAddress)
		}
		.presentationDetents([.medium])
	}

	private var title: String {
		switch editor {
		case .add: "Add Calibre Library"
		case .edit: "Edit Library"
		}
	}

	private var confirmLabel: String {
		switch editor {
		case .add: "Add"
		case .edit: "Save"
		}
	}

	private var footer: String {
		if case .edit(let library) = editor, address.trimmingCharacters(in: .whitespaces) != library.serverAddress {
			"Changing the server removes the books you’ve downloaded from this library."
		} else {
			"Turn on Calibre’s content server under Preferences → Sharing over the net, then enter its address."
		}
	}

	private func focusAddress() {
		focusedField = .address
	}

	private func save() {
		guard calibreLibraries.problem(withName: name, address: address) == nil else { return }

		switch editor {
		case .add:
			let added = calibreLibraries.add(name: name, address: address)
			library.selection = .calibre(added.id)
		case .edit(let calibreLibrary):
			calibreLibraries.update(calibreLibrary, name: name, address: address)
		}

		dismiss()
	}

	private func cancel() {
		dismiss()
	}
}
