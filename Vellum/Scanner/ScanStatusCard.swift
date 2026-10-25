import SwiftUI

/// Floats over the camera to show what happened to the last barcode, updating live as the lookup finishes.
struct ScanStatusCard: View {
	@Environment(Library.self) private var library
	@ScaledMetric(relativeTo: .body) private var coverWidth = Design.rowCoverWidth

	let lastScan: ScanResult?
	let addedCount: Int

	var body: some View {
		let status = status

		HStack {
			if let entry = status.entry {
				CoverImage(book: entry.book, width: coverWidth)
			} else {
				Image(systemName: status.systemImage)
					.font(.title)
					.foregroundStyle(status.isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
					.frame(width: coverWidth)
					.accessibilityHidden(true)
			}

			VStack(alignment: .leading, spacing: Design.rowTextSpacing) {
				Text(status.title)
					.font(.headline)
					.lineLimit(2)

				if let detail = status.detail {
					Text(detail)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}

				if addedCount > 0 {
					Text("^[\(addedCount) book](inflect: true) scanned")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding()
		.glassEffect(in: .rect(cornerRadius: Design.cardCornerRadius))
		.animation(.default, value: status)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.updatesFrequently)
	}

	private var status: ScanStatus {
		guard let lastScan else {
			return ScanStatus(systemImage: "barcode.viewfinder", title: "Point the camera at a book’s barcode", detail: "It’s usually on the back cover.")
		}

		let shelf = library.selectedShelf

		switch lastScan.outcome {
		case .notABook:
			return ScanStatus(systemImage: "exclamationmark.triangle.fill", title: "That barcode isn’t a book", detail: "Look for the one with an ISBN above it.", isWarning: true)

		case .duplicate(let isbn, let shelfName):
			let entry = shelf.entries.first { $0.isbn == isbn }
			return ScanStatus(entry: entry, systemImage: "checkmark.circle.fill", title: entry?.title ?? "Already added", detail: "Already on “\(shelfName)”", isWarning: true)

		case .queued(let isbn):
			if let entry = shelf.entries.first(where: { $0.isbn == isbn }) {
				return ScanStatus(entry: entry, systemImage: "checkmark.circle.fill", title: entry.title, detail: "Added to “\(shelf.name)”")
			}

			if case .failed(let message) = library.lookups(for: shelf.id).first(where: { $0.isbn == isbn })?.state {
				return ScanStatus(systemImage: "questionmark.circle.fill", title: "Couldn’t find ISBN \(isbn.digits)", detail: message, isWarning: true)
			}

			return ScanStatus(systemImage: "magnifyingglass", title: "Looking up ISBN \(isbn.digits)…")
		}
	}
}
