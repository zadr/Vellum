import SwiftUI

/// Theme, layout, and typography for the reader. Stays at half height so changes show on the page behind it.
struct ReaderAppearanceSheet: View {
	@Environment(\.dismiss) private var dismiss

	@AppStorage("reader-theme") private var theme = ReaderTheme.automatic
	@AppStorage("reader-mode") private var mode = ReaderMode.pages
	@AppStorage("reader-font") private var font = ReaderFont.charter
	@AppStorage("reader-text-scale") private var textScale = ReaderTypography.defaultTextScale
	@AppStorage("reader-line-height") private var lineHeight = ReaderTypography.defaultLineHeight
	@AppStorage("reader-paragraph-spacing") private var paragraphSpacing = ReaderTypography.defaultParagraphSpacing
	@AppStorage("reader-column-width") private var columnWidth = ReaderTypography.defaultColumnWidth
	@AppStorage("reader-styles") private var styles = ReaderStyleSettings()

	/// The widest column the current screen can hold.
	let maximumColumnWidth: Double

	var body: some View {
		NavigationStack {
			Form {
				Section {
					ScrollView(.horizontal) {
						HStack(spacing: Design.gridSpacing) {
							ForEach(ReaderTheme.allCases) { option in
								ReaderThemeSwatch(theme: option, isSelected: option == theme) {
									theme = option
								}
							}
						}
					}
					.scrollIndicators(.hidden)
				}

				Section {
					Picker("Layout", selection: $mode) {
						ForEach(ReaderMode.allCases) { mode in
							Label(mode.label, systemImage: mode.systemImage)
								.tag(mode)
						}
					}
					.pickerStyle(.segmented)
				}

				Section("Text") {
					Picker("Font", selection: $font) {
						ForEach(ReaderFont.allCases) { font in
							Text(font.label)
								.tag(font)
						}
					}

					ReaderSettingSlider(
						title: "Size",
						value: $textScale,
						range: ReaderTypography.textScales,
						step: 0.05,
						smallerImage: "textformat.size.smaller",
						largerImage: "textformat.size.larger",
						valueText: Self.percent
					)

					Picker("Justification", selection: $styles.justification) {
						ForEach(ReaderStyleSettings.Justification.allCases) { option in
							Text(option.label)
								.tag(option)
						}
					}
				}

				Section {
					Toggle("Book Line Height", isOn: $styles.bookLineHeight)

					if !styles.bookLineHeight {
						ReaderSettingSlider(
							title: "Line Height",
							value: $lineHeight,
							range: ReaderTypography.lineHeights,
							step: 0.05,
							smallerImage: "arrow.down.and.line.horizontal.and.arrow.up",
							largerImage: "arrow.up.and.line.horizontal.and.arrow.down",
							valueText: Self.multiple
						)
					}

					Toggle("Book Paragraph Spacing", isOn: $styles.bookParagraphSpacing)

					if !styles.bookParagraphSpacing {
						ReaderSettingSlider(
							title: "Paragraph Spacing",
							value: $paragraphSpacing,
							range: ReaderTypography.paragraphSpacings,
							step: 0.1,
							smallerImage: "text.alignleft",
							largerImage: "text.justify.leading",
							valueText: Self.multiple
						)
					}
				} header: {
					Text("Spacing")
				}

				Section("Page") {
					ReaderSettingSlider(
						title: "Column Width",
						value: $columnWidth,
						range: ReaderTypography.minimumColumnWidth...max(maximumColumnWidth, ReaderTypography.minimumColumnWidth + 10),
						step: 10,
						smallerImage: "arrow.right.and.line.vertical.and.arrow.left",
						largerImage: "arrow.left.and.line.vertical.and.arrow.right",
						valueText: Self.points
					)
				}

				Section {
					Toggle("Text Sizes", isOn: $styles.bookTextSizes)
					Toggle("Paragraph Indents", isOn: $styles.bookIndents)
					Toggle("Margins", isOn: $styles.bookMargins)
					Toggle("Drop Caps", isOn: $styles.bookDropCaps)
				} header: {
					Text("Book Styles")
				} footer: {
					Text("Turn these off to set every book the same way, whatever its own styles say.")
				}

				Section {
					Button("Reset to Defaults", action: reset)
				}
			}
			.navigationTitle("Appearance")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button(role: .close, action: close)
				}
			}
		}
		// Never taller than half the screen, so the page behind it always shows the result.
		.presentationDetents([.medium])
		.presentationBackgroundInteraction(.enabled)
	}

	private static func percent(_ value: Double) -> String {
		value.formatted(.percent.precision(.fractionLength(0)))
	}

	private static func multiple(_ value: Double) -> String {
		"\(value.formatted(.number.precision(.fractionLength(0...2))))×"
	}

	private static func points(_ value: Double) -> String {
		"\(value.formatted(.number.precision(.fractionLength(0)))) pt"
	}

	private func reset() {
		mode = .pages
		font = .charter
		textScale = ReaderTypography.defaultTextScale
		lineHeight = ReaderTypography.defaultLineHeight
		paragraphSpacing = ReaderTypography.defaultParagraphSpacing
		columnWidth = ReaderTypography.defaultColumnWidth
		styles = ReaderStyleSettings()
	}

	private func close() {
		dismiss()
	}
}
