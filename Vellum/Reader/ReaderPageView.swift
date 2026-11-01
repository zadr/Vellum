import SwiftUI

/// One page, drawn with Core Text.
struct ReaderPageView: View {
	let layout: BookLayout
	let index: Int
	let textColor: CGColor
	let previous: () -> Void
	let toggleChrome: () -> Void
	let next: () -> Void

	var body: some View {
		Canvas { context, _ in
			context.withCGContext { cgContext in
				layout.draw(page: index, in: cgContext, textColor: textColor)
			}
		}
		.accessibilityElement()
		.accessibilityLabel(layout.text(ofPage: index))
		.overlay {
			ReaderTapZones(previous: previous, toggleChrome: toggleChrome, next: next)
		}
	}
}
