import SwiftUI

struct ReaderAppearanceMenu: View {
	@AppStorage("reader-theme") private var theme = ReaderTheme.automatic
	@AppStorage("reader-font") private var font = ReaderFont.charter
	@AppStorage("reader-text-scale") private var textScale = 1.0

	var body: some View {
		Menu("Appearance", systemImage: "textformat.size") {
			Picker("Theme", selection: $theme) {
				ForEach(ReaderTheme.allCases) { theme in
					Text(theme.label)
						.tag(theme)
				}
			}

			Picker("Font", selection: $font) {
				ForEach(ReaderFont.allCases) { font in
					Text(font.label)
						.tag(font)
				}
			}
			.pickerStyle(.menu)

			Section("Text Size") {
				ControlGroup {
					Button("Smaller", systemImage: "textformat.size.smaller", action: shrinkText)
						.disabled(!canShrinkText)

					Button("Larger", systemImage: "textformat.size.larger", action: growText)
						.disabled(!canGrowText)
				}
			}
		}
		.menuActionDismissBehavior(.disabled)
	}

	private var scaleIndex: Int {
		ReaderTypography.textScales.firstIndex { $0 >= textScale } ?? ReaderTypography.textScales.count - 1
	}

	private var canShrinkText: Bool {
		scaleIndex > 0
	}

	private var canGrowText: Bool {
		scaleIndex < ReaderTypography.textScales.count - 1
	}

	private func shrinkText() {
		textScale = ReaderTypography.textScales[max(scaleIndex - 1, 0)]
	}

	private func growText() {
		textScale = ReaderTypography.textScales[min(scaleIndex + 1, ReaderTypography.textScales.count - 1)]
	}
}
