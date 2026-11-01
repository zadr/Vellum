import SwiftUI

/// A circle showing a theme's page and text colors.
struct ReaderThemeSwatch: View {
	@Environment(\.colorScheme) private var colorScheme

	let theme: ReaderTheme
	let isSelected: Bool
	let select: () -> Void

	var body: some View {
		let palette = theme.palette(for: colorScheme)

		Button(action: select) {
			VStack {
				Circle()
					.fill(palette.backgroundColor)
					.overlay {
						Text("Aa")
							.font(.subheadline)
							.foregroundStyle(Color(cgColor: palette.textColor))
					}
					.overlay {
						Circle()
							.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 3 : 1)
					}
					.frame(width: Design.themeSwatchSize, height: Design.themeSwatchSize)

				Text(theme.shortLabel)
					.font(.caption)
					.foregroundStyle(isSelected ? .primary : .secondary)
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel(theme.label)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}
