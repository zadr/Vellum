import SwiftUI

/// The book's table of contents. Choosing an entry jumps to it.
struct ContentsView: View {
	@Environment(\.dismiss) private var dismiss

	let book: ReaderBook
	let currentChapter: Int
	let select: (ReaderContentsEntry) -> Void

	var body: some View {
		let current = book.contentsEntry(forChapter: currentChapter)

		NavigationStack {
			ScrollViewReader { proxy in
				List(book.contents) { entry in
					let isCurrent = entry.id == current?.id

					Button {
						choose(entry)
					} label: {
						Text(entry.title)
							.bold(isCurrent)
							.padding(.leading, Double(entry.level) * Design.contentsIndent)
					}
					.foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
					.accessibilityAddTraits(isCurrent ? .isSelected : [])
				}
				.onAppear {
					if let current {
						proxy.scrollTo(current.id, anchor: .center)
					}
				}
			}
			.navigationTitle("Contents")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button(role: .close, action: close)
				}
			}
		}
		.presentationDetents([.medium, .large])
	}

	private func choose(_ entry: ReaderContentsEntry) {
		select(entry)
		dismiss()
	}

	private func close() {
		dismiss()
	}
}
