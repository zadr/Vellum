import SwiftUI
import VisionKit

/// Wraps VisionKit's live barcode scanner, reporting each distinct EAN-13 barcode once.
struct BarcodeScanner: UIViewControllerRepresentable {
	let onScan: (String) -> Void

	func makeUIViewController(context: Context) -> DataScannerViewController {
		let scanner = DataScannerViewController(
			recognizedDataTypes: [.barcode(symbologies: [.ean13])],
			qualityLevel: .balanced,
			recognizesMultipleItems: false,
			isHighFrameRateTrackingEnabled: false,
			isHighlightingEnabled: true
		)
		scanner.delegate = context.coordinator
		try? scanner.startScanning()
		return scanner
	}

	func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
		context.coordinator.onScan = onScan
	}

	static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
		scanner.stopScanning()
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(onScan: onScan)
	}

	final class Coordinator: DataScannerViewControllerDelegate {
		var onScan: (String) -> Void

		/// The scanner re-reports barcodes as they move in and out of view, so only pass each one along once.
		private var seen = Set<String>()

		init(onScan: @escaping (String) -> Void) {
			self.onScan = onScan
		}

		func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
			for item in addedItems {
				guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue else { continue }

				if seen.insert(payload).inserted {
					onScan(payload)
				}
			}
		}
	}
}
