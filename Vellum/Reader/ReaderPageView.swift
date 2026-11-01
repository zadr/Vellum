import SwiftUI

/// One page, drawn with Core Text. Tapping a link follows it; otherwise the outer thirds turn pages and the
/// middle shows the controls.
struct ReaderPageView: View {
	let layout: BookLayout
	let index: Int
	let textColor: CGColor
	let previous: () -> Void
	let toggleChrome: () -> Void
	let next: () -> Void
	let follow: (URL) -> Void

	var body: some View {
		Canvas { context, _ in
			context.withCGContext { cgContext in
				layout.draw(page: index, in: cgContext, textColor: textColor)
			}
		}
		.contentShape(.rect)
		// The location decides between following a link and turning the page, so this can't be a button.
		.onTapGesture(coordinateSpace: .local, perform: tapped)
		.onGeometryChange(for: Double.self) { proxy in
			proxy.size.width
		} action: { width in
			pageWidth = width
		}
		.accessibilityElement()
		.accessibilityLabel(layout.text(ofPage: index))
		.accessibilityAddTraits(.isButton)
		.accessibilityAction(named: "Next Page", next)
		.accessibilityAction(named: "Previous Page", previous)
		.accessibilityAction(named: "Show or Hide Controls", toggleChrome)
	}

	@State private var pageWidth = 0.0

	private func tapped(at location: CGPoint) {
		if let link = layout.link(at: location, inPage: index) {
			follow(link)
		} else if location.x < pageWidth * 0.3 {
			previous()
		} else if location.x > pageWidth * 0.7 {
			next()
		} else {
			toggleChrome()
		}
	}
}
