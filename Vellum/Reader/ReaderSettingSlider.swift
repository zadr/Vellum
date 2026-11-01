import SwiftUI

/// A labelled slider for a reading setting. The setting only changes when the slider is let go,
/// because every change lays the whole book out again.
struct ReaderSettingSlider: View {
	let title: String
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let smallerImage: String
	let largerImage: String
	let valueText: (Double) -> String

	@State private var draft = 0.0

	var body: some View {
		VStack(alignment: .leading) {
			LabeledContent(title) {
				Text(valueText(draft))
					.monospacedDigit()
			}

			Slider(value: $draft, in: range, step: step) {
				Text(title)
			} minimumValueLabel: {
				Image(systemName: smallerImage)
			} maximumValueLabel: {
				Image(systemName: largerImage)
			} onEditingChanged: { isEditing in
				if !isEditing {
					commit()
				}
			}
			.accessibilityValue(valueText(draft))
		}
		.onAppear(perform: resetDraft)
		.onChange(of: value, resetDraft)
	}

	private func resetDraft() {
		draft = min(max(value, range.lowerBound), range.upperBound)
	}

	private func commit() {
		value = draft
	}
}
