import SwiftUI

/// The book as one continuous column of text, scrolled vertically.
struct ReaderScroll: View {
	@Bindable var model: ReaderModel
	let layout: BookLayout
	let textColor: CGColor

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 0) {
				ForEach(layout.pages.indices, id: \.self) { index in
					ReaderScrollPiece(layout: layout, index: index, textColor: textColor, toggleChrome: model.toggleChrome)
						.padding(.top, index > 0 && layout.isChapterStart(index) ? Design.readerChapterGap : 0)
				}
			}
			.scrollTargetLayout()
		}
		.scrollPosition(id: $model.visiblePage, anchor: .top)
		.scrollIndicators(.hidden)
		// A new layout has different pieces, so start a fresh scroll view at the reader's place.
		.id(ObjectIdentifier(layout))
	}
}
