import SwiftUI

/// One piece of a scrolling book. Pieces are trimmed to their text, so they stack into a seamless column.
/// Tapping a link follows it; tapping anywhere else shows or hides the controls.
struct ReaderScrollPiece: View {
	let layout: BookLayout
	let index: Int
	let textColor: CGColor
	let toggleChrome: () -> Void
	let follow: (URL) -> Void

	var body: some View {
		Canvas { context, _ in
			context.withCGContext { cgContext in
				layout.draw(page: index, in: cgContext, textColor: textColor)
			}
		}
		.frame(height: layout.pages[index].height)
		.contentShape(.rect)
		// The location decides between following a link and showing the controls, so this can't be a button.
		.onTapGesture(coordinateSpace: .local, perform: tapped)
		.accessibilityElement()
		.accessibilityLabel(layout.text(ofPage: index))
		.accessibilityAddTraits(.isButton)
		.accessibilityHint("Shows or hides the reading controls.")
		.accessibilityAction(named: "Show or Hide Controls", toggleChrome)
	}

	private func tapped(at location: CGPoint) {
		if let link = layout.link(at: location, inPage: index) {
			follow(link)
		} else {
			toggleChrome()
		}
	}
}
