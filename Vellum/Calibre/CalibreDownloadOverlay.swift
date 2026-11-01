import SwiftUI

/// Dims a cover and shows how much of the book has downloaded.
struct CalibreDownloadOverlay: View {
	let progress: Double

	var body: some View {
		ZStack {
			Rectangle()
				.fill(.black.opacity(0.45))

			Gauge(value: progress) {
				Text("Downloading")
			}
			.gaugeStyle(.accessoryCircularCapacity)
			.tint(.white)
		}
	}
}
