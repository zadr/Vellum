import SwiftUI

/// A book's cover, with a tinted placeholder while it loads or when there isn't one.
struct CoverImage: View {
	let url: URL?
	let width: Double

	init(url: URL?, width: Double) {
		self.url = url
		self.width = width
	}

	/// The cover Open Library has for the book.
	init(book: Book, width: Double) {
		self.init(url: book.coverURL, width: width)
	}

	var body: some View {
		AsyncImage(url: url, transaction: Transaction(animation: .easeOut)) { phase in
			if let image = phase.image {
				image
					.resizable()
					.scaledToFill()
			} else {
				CoverPlaceholder(isLoading: phase.error == nil)
			}
		}
		.frame(width: width, height: width / Design.coverAspectRatio)
		.clipShape(.rect(cornerRadius: Design.coverCornerRadius))
		.overlay {
			RoundedRectangle(cornerRadius: Design.coverCornerRadius)
				.strokeBorder(.separator, lineWidth: 0.5)
		}
		.accessibilityHidden(true)
	}
}

#Preview {
	CoverImage(book: .preview, width: 120)
		.padding()
}
