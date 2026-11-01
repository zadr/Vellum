import SwiftUI

/// Invisible buttons over a page: the outer thirds turn pages, the middle shows the controls.
/// They live inside each page so swiping between pages still works.
struct ReaderTapZones: View {
	let previous: () -> Void
	let toggleChrome: () -> Void
	let next: () -> Void

	var body: some View {
		HStack(spacing: 0) {
			Button(action: previous) {
				Color.clear
					.contentShape(.rect)
			}
			.accessibilityLabel("Previous Page")
			.containerRelativeFrame(.horizontal, count: 10, span: 3, spacing: 0)

			Button(action: toggleChrome) {
				Color.clear
					.contentShape(.rect)
			}
			.accessibilityLabel("Show or Hide Controls")

			Button(action: next) {
				Color.clear
					.contentShape(.rect)
			}
			.accessibilityLabel("Next Page")
			.containerRelativeFrame(.horizontal, count: 10, span: 3, spacing: 0)
		}
		.buttonStyle(.plain)
	}
}
