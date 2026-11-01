import SwiftUI

/// Where the reader is: the part of the book, how far through it they are, and how much of the book is read.
struct ReaderBottomBar: View {
	let model: ReaderModel
	let title: String

	var body: some View {
		VStack(spacing: Design.rowTextSpacing) {
			Text(model.book.contentsEntry(forChapter: model.chapter)?.title ?? title)
				.font(.subheadline)
				.bold()
				.lineLimit(1)

			Group {
				if model.layout?.mode == .scroll {
					Text("\(model.fractionOfChapterRead, format: .percent.precision(.fractionLength(0))) of chapter · \(model.fractionRead, format: .percent.precision(.fractionLength(0))) of book")
				} else {
					Text("Page \(model.pageInChapter) of \(model.pagesInChapter) · \(model.fractionRead, format: .percent.precision(.fractionLength(0))) read")
				}
			}
			.font(.footnote)
			.foregroundStyle(.secondary)
			.monospacedDigit()
		}
		.padding()
		.glassEffect()
		.padding(.horizontal)
	}
}
