import SwiftUI

/// A row of tappable stars. Tapping the current rating again clears it.
struct RatingView: View {
	@Binding var rating: Int

	var body: some View {
		HStack(spacing: 0) {
			ForEach(1...Design.maximumRating, id: \.self) { star in
				Button("\(star) stars", systemImage: star <= rating ? "star.fill" : "star") {
					select(star)
				}
				.labelStyle(.iconOnly)
				.font(.title2)
				.foregroundStyle(star <= rating ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
				.frame(minWidth: 44, minHeight: 44)
				.contentShape(.rect)
			}
		}
		.buttonStyle(.plain)
		.sensoryFeedback(.selection, trigger: rating)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Rating")
		.accessibilityValue(rating == 0 ? "Not rated" : "\(rating) of \(Design.maximumRating) stars")
		.accessibilityAdjustableAction { direction in
			switch direction {
			case .increment: rating = min(rating + 1, Design.maximumRating)
			case .decrement: rating = max(rating - 1, 0)
			@unknown default: break
			}
		}
	}

	private func select(_ star: Int) {
		rating = rating == star ? 0 : star
	}
}

#Preview {
	@Previewable @State var rating = 3
	RatingView(rating: $rating)
}
