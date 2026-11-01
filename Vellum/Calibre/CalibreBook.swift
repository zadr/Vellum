import Foundation

/// A book in the user's Calibre library, as described by their Calibre content server.
struct CalibreBook: Codable, Identifiable, Hashable {
	let id: Int
	var title: String
	var authors: [String]
	var formats: [String]
	var series: String?
	var seriesIndex: Double?
	var dateAdded: Date?

	var authorLine: String? {
		authors.isEmpty ? nil : authors.formatted(.list(type: .and))
	}

	/// Used for sorting by author; falls back to the title so unattributed books still sort sensibly.
	var authorSortKey: String {
		authors.first ?? title
	}

	var seriesLine: String? {
		guard let series else { return nil }
		guard let seriesIndex else { return series }
		return "\(series) #\(seriesIndex.formatted())"
	}

	/// Vellum only reads EPUBs, so books without one are listed but can't be opened.
	var hasEPUB: Bool {
		formats.contains { $0.caseInsensitiveCompare("epub") == .orderedSame }
	}

	func matches(_ search: String) -> Bool {
		title.localizedStandardContains(search)
			|| (authorLine?.localizedStandardContains(search) ?? false)
			|| (series?.localizedStandardContains(search) ?? false)
	}
}
