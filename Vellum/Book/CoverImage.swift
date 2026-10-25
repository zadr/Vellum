import SwiftUI

/// A book's cover from Open Library, with a tinted placeholder while it loads or when there isn't one.
struct CoverImage: View {
	let book: Book
	let width: Double

	var body: some View {
		AsyncImage(url: book.coverURL, transaction: Transaction(animation: .easeOut)) { phase in
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
