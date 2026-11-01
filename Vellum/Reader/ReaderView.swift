import SwiftUI

/// Full-screen reading for a downloaded book. Swipe or tap the page edges to turn pages; tap the middle for controls.
struct ReaderView: View {
	private enum LoadState {
		case loading
		case ready(ReaderModel)
		case failed(String)
	}

	@Environment(CalibreLibrary.self) private var calibre
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme

	@AppStorage("reader-theme") private var theme = ReaderTheme.automatic

	let book: CalibreBook

	@State private var state = LoadState.loading

	var body: some View {
		let palette = theme.palette(for: colorScheme)

		ZStack {
			palette.backgroundColor
				.ignoresSafeArea()

			switch state {
			case .loading:
				ProgressView()
			case .ready(let model):
				ReaderContent(model: model, palette: palette, title: book.title, close: close)
			case .failed(let message):
				ContentUnavailableView {
					Label("Can’t Open This Book", systemImage: "book.closed")
				} description: {
					Text(message)
				} actions: {
					Button("Close", action: close)
						.buttonStyle(.borderedProminent)
				}
			}
		}
		.environment(\.colorScheme, palette.colorScheme)
		.statusBarHidden()
		.task {
			await open()
		}
	}

	private func open() async {
		guard case .loading = state else { return }

		do {
			let readerBook = try await ReaderBook.open(calibre.bookURL(for: book.id), unpackingTo: calibre.unpackedURL(for: book.id))
			guard !readerBook.chapters.isEmpty else {
				state = .failed("This book doesn’t have any pages.")
				return
			}

			let id = book.id
			let model = ReaderModel(book: readerBook, position: calibre.position(for: id)) { [calibre] position in
				calibre.setPosition(position, for: id)
			}
			state = .ready(model)
		} catch {
			state = .failed("The EPUB couldn’t be read. Try removing the download and downloading it again.")
		}
	}

	private func close() {
		dismiss()
	}
}
