import SwiftUI

/// Where the reader is: the part of the book, the page within it, and how much of the book is read.
struct ReaderBottomBar: View {
	let model: ReaderModel
	let title: String

	var body: some View {
		VStack(spacing: Design.rowTextSpacing) {
			Text(model.book.contentsEntry(forChapter: model.chapter)?.title ?? title)
				.font(.subheadline)
				.bold()
				.lineLimit(1)

			Text("Page \(model.pageInChapter) of \(model.pagesInChapter) · \(model.fractionRead, format: .percent.precision(.fractionLength(0))) read")
				.font(.footnote)
				.foregroundStyle(.secondary)
				.monospacedDigit()
		}
		.padding()
		.glassEffect()
		.padding(.horizontal)
	}
}
