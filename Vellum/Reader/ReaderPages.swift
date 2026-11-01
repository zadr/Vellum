import SwiftUI

/// Every page of the book side by side, swiped through one at a time.
struct ReaderPages: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Bindable var model: ReaderModel
	let layout: BookLayout
	let textColor: CGColor

	var body: some View {
		ScrollView(.horizontal) {
			LazyHStack(spacing: 0) {
				ForEach(layout.pages.indices, id: \.self) { index in
					ReaderPageView(
						layout: layout,
						index: index,
						textColor: textColor,
						previous: showPreviousPage,
						toggleChrome: model.toggleChrome,
						next: showNextPage,
						follow: model.follow
					)
					.containerRelativeFrame([.horizontal, .vertical])
				}
			}
			.scrollTargetLayout()
		}
		.scrollTargetBehavior(.paging)
		.scrollPosition(id: $model.visiblePage)
		.scrollIndicators(.hidden)
		// A new layout has different pages, so start a fresh scroll view at the reader's place.
		.id(ObjectIdentifier(layout))
	}

	private func showPreviousPage() {
		withAnimation(reduceMotion ? nil : .smooth) {
			model.previousPage()
		}
	}

	private func showNextPage() {
		withAnimation(reduceMotion ? nil : .smooth) {
			model.nextPage()
		}
	}
}
