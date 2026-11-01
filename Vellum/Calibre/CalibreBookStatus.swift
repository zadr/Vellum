import SwiftUI

/// What's going on with a book: a failed download, reading progress, or that it isn't downloaded yet.
struct CalibreBookStatus: View {
	@Environment(CalibreLibrary.self) private var calibre

	let book: CalibreBook

	var body: some View {
		if let error = calibre.downloadErrors[book.id] {
			Label(error, systemImage: "exclamationmark.triangle.fill")
				.foregroundStyle(.red)
				.lineLimit(2)
		} else if !book.hasEPUB {
			Text("No EPUB")
				.foregroundStyle(.secondary)
		} else if let fraction = calibre.position(for: book.id)?.fractionRead, calibre.isDownloaded(book.id) {
			ProgressView(value: fraction)
				.accessibilityLabel("\(fraction, format: .percent.precision(.fractionLength(0))) read")
		} else if !calibre.isDownloaded(book.id) && calibre.downloadProgress[book.id] == nil {
			Label("Not Downloaded", systemImage: "arrow.down.circle")
				.labelStyle(.iconOnly)
				.foregroundStyle(.secondary)
		}
	}
}
