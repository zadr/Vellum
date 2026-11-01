import SwiftUI

/// The series a book belongs to, plus whether it's downloaded, downloading, or can't be read.
struct CalibreBookRowFootnote: View {
	@Environment(CalibreLibrary.self) private var calibre

	let book: CalibreBook

	var body: some View {
		VStack(alignment: .leading, spacing: Design.rowTextSpacing) {
			if let seriesLine = book.seriesLine {
				Text(seriesLine)
					.foregroundStyle(.secondary)
			}

			if let progress = calibre.downloadProgress[book.id] {
				ProgressView(value: progress)
					.accessibilityLabel("Downloading")
			} else if let error = calibre.downloadErrors[book.id] {
				Label(error, systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.red)
			} else if calibre.isDownloaded(book.id) {
				Label("Downloaded", systemImage: "arrow.down.circle.fill")
					.foregroundStyle(.tint)
			} else if !book.hasEPUB {
				Text("No EPUB · \(book.formats.map { $0.uppercased() }.formatted(.list(type: .and)))")
					.foregroundStyle(.secondary)
			}
		}
		.font(.footnote)
		.labelStyle(.titleAndIcon)
	}
}
