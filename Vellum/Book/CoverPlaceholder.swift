import SwiftUI

struct CoverPlaceholder: View {
	let isLoading: Bool

	var body: some View {
		Rectangle()
			.fill(Color.accentColor.gradient)
			.overlay {
				Image(systemName: "book.closed.fill")
					.font(.title3)
					.foregroundStyle(.white.secondary)
					.opacity(isLoading ? 0 : 1)
			}
	}
}
