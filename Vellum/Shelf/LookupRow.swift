import SwiftUI

/// A placeholder row for a book that's still being looked up, or couldn't be found.
struct LookupRow: View {
	@Environment(Library.self) private var library
	@ScaledMetric(relativeTo: .body) private var coverWidth = Design.rowCoverWidth

	let lookup: Lookup

	var body: some View {
		HStack {
			RoundedRectangle(cornerRadius: Design.coverCornerRadius)
				.fill(.fill.tertiary)
				.frame(width: coverWidth, height: coverWidth / Design.coverAspectRatio)
				.overlay {
					switch lookup.state {
					case .loading:
						ProgressView()
					case .failed:
						Image(systemName: "questionmark")
							.font(.title3)
							.foregroundStyle(.secondary)
					}
				}
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: Design.rowTextSpacing) {
				switch lookup.state {
				case .loading:
					Text("Looking up book…")
						.font(.headline)
				case .failed(let message):
					Text("Couldn’t add book")
						.font(.headline)
					Text(message)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}

				Text("ISBN \(lookup.isbn.digits)")
					.font(.footnote.monospacedDigit())
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			if case .failed = lookup.state {
				Button("Retry", action: retry)
					.buttonStyle(.bordered)
			}
		}
		.swipeActions {
			Button("Dismiss", systemImage: "xmark", role: .destructive, action: dismiss)
		}
	}

	private func retry() {
		library.retry(lookup)
	}

	private func dismiss() {
		library.dismiss(lookup)
	}
}
