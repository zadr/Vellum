import SwiftUI

/// A book's cover from the Calibre server, sized to fill the width it's given.
/// Shows download progress over the cover, and fades books Vellum can't open.
struct CalibreCover: View {
	@Environment(CalibreLibrary.self) private var calibre

	let book: CalibreBook

	var body: some View {
		// The cell sets the shape; covers with other proportions are cropped to fit it.
		Color.clear
			.aspectRatio(Design.coverAspectRatio, contentMode: .fit)
			.overlay {
				AsyncImage(url: calibre.thumbnailURL(for: book.id), transaction: Transaction(animation: .easeOut)) { phase in
					if let image = phase.image {
						image
							.resizable()
							.scaledToFill()
					} else {
						CoverPlaceholder(isLoading: phase.error == nil)
					}
				}
			}
			.overlay {
			if let progress = calibre.downloadProgress[book.id] {
				CalibreDownloadOverlay(progress: progress)
			}
		}
		.clipShape(.rect(cornerRadius: Design.coverCornerRadius))
		.overlay {
			RoundedRectangle(cornerRadius: Design.coverCornerRadius)
				.strokeBorder(.separator, lineWidth: 0.5)
		}
		.shadow(color: .black.opacity(0.15), radius: 6, y: 3)
		.saturation(book.hasEPUB ? 1 : 0)
		.accessibilityHidden(true)
	}
}
