import SwiftUI

/// Continuous barcode scanning: every book scanned is added to the selected shelf until the user is done.
struct ScannerView: View {
	@Environment(Library.self) private var library
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL

	@State private var access = CameraAccess.checking
	@State private var lastScan: ScanResult?
	@State private var addedCount = 0
	@State private var isEnteringISBN = false

	var body: some View {
		NavigationStack {
			ZStack {
				switch access {
				case .checking:
					ProgressView()
				case .granted:
					BarcodeScanner(onScan: handle)
						.ignoresSafeArea()
				case .denied:
					ContentUnavailableView {
						Label("Camera Access Needed", systemImage: "camera")
					} description: {
						Text("Allow Vellum to use the camera in Settings to scan book barcodes.")
					} actions: {
						Button("Open Settings", action: openSettings)
							.buttonStyle(.borderedProminent)
					}
				case .unsupported:
					ContentUnavailableView {
						Label("Scanning Unavailable", systemImage: "barcode.viewfinder")
					} description: {
						Text("This device can’t scan barcodes, but you can type in an ISBN instead.")
					} actions: {
						Button("Enter ISBN", action: enterISBN)
							.buttonStyle(.borderedProminent)
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.safeAreaInset(edge: .bottom) {
				if access == .granted {
					ScanStatusCard(lastScan: lastScan, addedCount: addedCount)
						.padding()
				}
			}
			.navigationTitle("Scan Books")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("Enter ISBN", systemImage: "keyboard", action: enterISBN)
				}

				ToolbarItem(placement: .confirmationAction) {
					Button("Done", role: .confirm, action: close)
				}
			}
			.sheet(isPresented: $isEnteringISBN) {
				ISBNEntryView()
			}
		}
		.sensoryFeedback(trigger: lastScan) { _, scan in
			scan?.isSuccess == true ? .success : .warning
		}
		.task {
			access = await CameraAccess.request()
		}
	}

	private func handle(_ payload: String) {
		guard let isbn = ISBN(payload) else {
			lastScan = ScanResult(outcome: .notABook)
			return
		}

		switch library.add(isbn) {
		case .queued:
			addedCount += 1
			lastScan = ScanResult(outcome: .queued(isbn))
		case .alreadyQueued:
			break
		case .duplicate(let shelfName):
			lastScan = ScanResult(outcome: .duplicate(isbn, shelfName: shelfName))
		}
	}

	private func enterISBN() {
		isEnteringISBN = true
	}

	private func openSettings() {
		if let url = URL(string: UIApplication.openSettingsURLString) {
			openURL(url)
		}
	}

	private func close() {
		dismiss()
	}
}
