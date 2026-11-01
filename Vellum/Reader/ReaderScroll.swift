import SwiftUI

/// The book as one continuous column of text, scrolled vertically.
/// Pieces sit at exact offsets worked out from the layout, and only those near the screen are drawn, so the scroll's
/// height is exact and a saved line can be put precisely at the top of the screen.
struct ReaderScroll: View {
	let model: ReaderModel
	let layout: BookLayout
	let textColor: CGColor

	@State private var scrollPosition = ScrollPosition()
	/// The scroll offset in the terms `scrollTo(y:)` uses, which count the top safe-area inset.
	@State private var offset = 0.0
	@State private var viewportHeight = 0.0

	var body: some View {
		let metrics = model.scrollMetrics
		let drawn = metrics?.pieces(from: offset - viewportHeight, to: offset + viewportHeight * 2) ?? 0..<0

		ScrollView {
			ZStack(alignment: .top) {
				Color.clear
					.frame(height: metrics?.contentHeight ?? 0)

				ForEach(drawn, id: \.self) { index in
					ReaderScrollPiece(layout: layout, index: index, textColor: textColor, toggleChrome: model.toggleChrome, follow: model.follow)
						.offset(y: metrics?.tops[index] ?? 0)
				}
			}
			.frame(maxWidth: .infinity, alignment: .top)
		}
		.scrollPosition($scrollPosition)
		.scrollIndicators(.hidden)
		.onScrollGeometryChange(for: ReaderScrollState.self) { geometry in
			ReaderScrollState(offset: geometry.contentOffset.y + geometry.contentInsets.top, height: geometry.containerSize.height)
		} action: { _, state in
			offset = state.offset
			viewportHeight = state.height
			model.scrolled(to: state.offset)
		}
		.onScrollPhaseChange { oldPhase, newPhase in
			// Only scrolling the reader did counts, not the scroll back to their place after a relayout.
			if newPhase == .idle, oldPhase == .interacting || oldPhase == .decelerating {
				model.scrollingStopped(at: offset)
			}
		}
		.onAppear(perform: restorePosition)
		.onChange(of: model.jump?.number) {
			if let page = model.jump?.page {
				scrollPosition.scrollTo(y: model.scrollOffset(ofPiece: page))
			}
		}
		// A new layout has different pieces, so start a fresh scroll view at the reader's place.
		.id(ObjectIdentifier(layout))
	}

	private func restorePosition() {
		offset = model.savedScrollOffset
		scrollPosition.scrollTo(y: offset)
	}
}
