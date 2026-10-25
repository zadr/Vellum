import SwiftUI

/// Adds a book by typing its ISBN, for when there's no barcode or no camera.
struct ISBNEntryView: View {
	@Environment(Library.self) private var library
	@Environment(\.dismiss) private var dismiss

	@State private var text = ""
	@State private var duplicateMessage: String?
	@FocusState private var isFocused: Bool

	var body: some View {
		let isbn = ISBN(text)
		let problem = duplicateMessage ?? ISBN.problem(with: text)

		NavigationStack {
			Form {
				Section {
					TextField("ISBN", text: $text, prompt: Text(verbatim: "978-0-14-032872-1"))
						.font(.title3.monospacedDigit())
						.keyboardType(.numbersAndPunctuation)
						.textInputAutocapitalization(.characters)
						.autocorrectionDisabled()
						.submitLabel(.done)
						.focused($isFocused)
						.onSubmit(add)
				} footer: {
					if let problem {
						Text(problem)
							.foregroundStyle(.red)
					} else {
						Text("You’ll find the ISBN on the back cover or the copyright page. It’s 10 or 13 digits long.")
					}
				}
			}
			.navigationTitle("Enter ISBN")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", role: .cancel, action: cancel)
				}

				ToolbarItem(placement: .confirmationAction) {
					Button("Add", role: .confirm, action: add)
						.disabled(isbn == nil || duplicateMessage != nil)
				}
			}
			.onChange(of: text) {
				duplicateMessage = nil
			}
			.onAppear {
				isFocused = true
			}
		}
		.presentationDetents([.medium])
	}

	private func add() {
		guard let isbn = ISBN(text) else { return }

		switch library.add(isbn) {
		case .queued, .alreadyQueued:
			dismiss()
		case .duplicate(let shelfName):
			duplicateMessage = "That book is already on “\(shelfName)”."
		}
	}

	private func cancel() {
		dismiss()
	}
}

#Preview {
	ISBNEntryView()
		.environment(Library())
}
