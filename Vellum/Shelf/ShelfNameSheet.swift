import SwiftUI

/// Names a new shelf, or renames an existing one.
struct ShelfNameSheet: View {
	@Environment(Library.self) private var library
	@Environment(\.dismiss) private var dismiss

	let editor: ShelfNameEditor

	@State private var name: String
	@FocusState private var isFocused: Bool

	init(editor: ShelfNameEditor) {
		self.editor = editor

		if case .rename(let shelf) = editor {
			_name = State(initialValue: shelf.name)
		} else {
			_name = State(initialValue: "")
		}
	}

	var body: some View {
		let problem = library.problem(withShelfName: name, renaming: renamingID)

		NavigationStack {
			Form {
				Section {
					TextField("Shelf Name", text: $name, prompt: Text("To Read, Favorites, Lent Out…"))
						.textInputAutocapitalization(.words)
						.submitLabel(.done)
						.focused($isFocused)
						.onSubmit(save)
				} footer: {
					// Only complain about names that are taken; an empty field just disables Save.
					if !name.trimmingCharacters(in: .whitespaces).isEmpty, let problem {
						Text(problem)
							.foregroundStyle(.red)
					}
				}
			}
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", role: .cancel, action: cancel)
				}

				ToolbarItem(placement: .confirmationAction) {
					Button("Save", role: .confirm, action: save)
						.disabled(problem != nil)
				}
			}
			.onAppear {
				isFocused = true
			}
		}
		.presentationDetents([.medium])
	}

	private var title: String {
		switch editor {
		case .create: "New Shelf"
		case .rename: "Rename Shelf"
		}
	}

	private var renamingID: Shelf.ID? {
		if case .rename(let shelf) = editor { shelf.id } else { nil }
	}

	private func save() {
		guard library.problem(withShelfName: name, renaming: renamingID) == nil else { return }

		switch editor {
		case .create:
			library.createShelf(named: name)
		case .rename(let shelf):
			library.renameShelf(shelf.id, to: name)
		}

		dismiss()
	}

	private func cancel() {
		dismiss()
	}
}
