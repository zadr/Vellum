import SwiftUI

/// One piece of a scrolling book. Pieces are trimmed to their text, so they stack into a seamless column.
struct ReaderScrollPiece: View {
	let layout: BookLayout
	let index: Int
	let textColor: CGColor
	let toggleChrome: () -> Void

	var body: some View {
		Button(action: toggleChrome) {
			Canvas { context, _ in
				context.withCGContext { cgContext in
					layout.draw(page: index, in: cgContext, textColor: textColor)
				}
			}
			.frame(height: layout.pages[index].height)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(layout.text(ofPage: index))
		.accessibilityHint("Shows or hides the reading controls.")
	}
}
