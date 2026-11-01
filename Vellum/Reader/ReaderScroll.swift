import SwiftUI

/// The book as one continuous column of text, scrolled vertically.
struct ReaderScroll: View {
	let model: ReaderModel
	let layout: BookLayout
	let textColor: CGColor

	@State private var scrollPosition = ScrollPosition(idType: Int.self)
	/// The scroll offset in the terms `scrollTo(y:)` uses, which count the top safe-area inset.
	@State private var scrollOffset = 0.0

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 0) {
				ForEach(layout.pages.indices, id: \.self) { index in
					ReaderScrollPiece(layout: layout, index: index, textColor: textColor, toggleChrome: model.toggleChrome, follow: model.follow)
						.padding(.top, index > 0 && layout.isChapterStart(index) ? Design.readerChapterGap : 0)
						.onGeometryChange(for: Double.self) { proxy in
							proxy.frame(in: .scrollView).minY
						} action: { top in
							model.scrollPiece(index, movedTo: top)
						}
						.onDisappear {
							model.scrollPieceDisappeared(index)
						}
				}
			}
			.scrollTargetLayout()
		}
		.scrollPosition($scrollPosition)
		.scrollIndicators(.hidden)
		.onScrollGeometryChange(for: Double.self) { geometry in
			geometry.contentOffset.y + geometry.contentInsets.top
		} action: { _, offset in
			scrollOffset = offset
		}
		.onScrollPhaseChange { _, phase in
			if phase == .idle {
				model.scrollingStopped()
			}
		}
		.task {
			await restorePosition()
		}
		.onChange(of: model.jump?.number) {
			if let page = model.jump?.page {
				scrollPosition.scrollTo(id: page, anchor: .top)
			}
		}
		// A new layout has different pieces, so start a fresh scroll view at the reader's place.
		.id(ObjectIdentifier(layout))
	}

	/// Scrolls to the saved piece, then down to the saved line within it once that piece has settled at the top.
	private func restorePosition() async {
		let target = model.scrollRestoreTarget
		scrollPosition.scrollTo(id: target.piece, anchor: .top)

		// Wait until the piece stops moving. Where it settles is the top edge pieces are measured against.
		var previous: Double?
		for _ in 0..<40 {
			try? await Task.sleep(for: .milliseconds(25))

			guard let top = model.pieceTop(target.piece) else { continue }
			if top == previous {
				model.scrollTopEdge = top
				if target.y > 0 {
					scrollPosition.scrollTo(y: scrollOffset + target.y)
				}
				return
			}
			previous = top
		}
	}
}
