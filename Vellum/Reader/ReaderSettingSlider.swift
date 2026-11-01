import SwiftUI

/// A labelled slider for a reading setting. The page behind updates as it moves.
struct ReaderSettingSlider: View {
	let title: String
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let smallerImage: String
	let largerImage: String
	let valueText: (Double) -> String

	var body: some View {
		VStack(alignment: .leading) {
			LabeledContent(title) {
				Text(valueText(value))
					.monospacedDigit()
			}

			Slider(value: $value, in: range, step: step) {
				Text(title)
			} minimumValueLabel: {
				Image(systemName: smallerImage)
			} maximumValueLabel: {
				Image(systemName: largerImage)
			}
			.accessibilityValue(valueText(value))
		}
	}
}
