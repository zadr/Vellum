import SwiftUI

/// The pages of an open book, with the controls that appear over them.
struct ReaderContent: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@AppStorage("reader-mode") private var mode = ReaderMode.pages
	@AppStorage("reader-font") private var font = ReaderFont.charter
	@AppStorage("reader-text-scale") private var textScale = ReaderTypography.defaultTextScale
	@AppStorage("reader-line-height") private var lineHeight = ReaderTypography.defaultLineHeight
	@AppStorage("reader-paragraph-spacing") private var paragraphSpacing = ReaderTypography.defaultParagraphSpacing
	@AppStorage("reader-column-width") private var columnWidth = ReaderTypography.defaultColumnWidth
	@ScaledMetric(relativeTo: .body) private var baseTextSize = Design.readerTextSize

	let model: ReaderModel
	let palette: ReaderPalette
	let title: String
	let close: () -> Void

	@State private var pageSize = CGSize.zero
	@State private var isShowingContents = false
	@State private var isShowingAppearance = false

	var body: some View {
		let request = ReaderLayoutRequest(pageSize: pageSize, typography: typography, mode: mode)

		ZStack {
			if let layout = model.layout {
				switch layout.mode {
				case .pages:
					ReaderPages(model: model, layout: layout, textColor: palette.textColor)
				case .scroll:
					ReaderScroll(model: model, layout: layout, textColor: palette.textColor)
				}
			} else if let error = model.layoutError {
				ContentUnavailableView("Can’t Show This Book", systemImage: "book.closed", description: Text(error))
			}

			if model.layout == nil && model.isLayingOut {
				ProgressView()
			}
		}
		// Fill the screen even before there are pages, so there's a size to lay them out for.
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onGeometryChange(for: CGSize.self) { proxy in
			proxy.size
		} action: { size in
			pageSize = size
		}
		.task(id: request) {
			await model.layOut(pageSize: request.pageSize, typography: request.typography, mode: request.mode)
		}
		.overlay(alignment: .top) {
			if model.isChromeVisible {
				ReaderTopBar(hasContents: !model.book.contents.isEmpty, showContents: showContents, showAppearance: showAppearance, close: close)
					.transition(chromeTransition(from: .top))
			}
		}
		.overlay(alignment: .bottom) {
			if model.isChromeVisible {
				ReaderBottomBar(model: model, title: title)
					.transition(chromeTransition(from: .bottom))
			}
		}
		.animation(.snappy, value: model.isChromeVisible)
		.sheet(isPresented: $isShowingContents) {
			ContentsView(book: model.book, currentChapter: model.chapter, select: model.go)
		}
		.sheet(isPresented: $isShowingAppearance) {
			ReaderAppearanceSheet(maximumColumnWidth: ReaderTypography.maximumColumnWidth(forPageWidth: pageSize.width))
		}
	}

	private var typography: ReaderTypography {
		ReaderTypography(
			font: font,
			size: (baseTextSize * textScale).rounded(),
			lineHeight: lineHeight,
			paragraphSpacing: paragraphSpacing,
			columnWidth: columnWidth
		)
	}

	private func chromeTransition(from edge: Edge) -> AnyTransition {
		reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
	}

	private func showContents() {
		isShowingContents = true
	}

	private func showAppearance() {
		isShowingAppearance = true
	}
}
