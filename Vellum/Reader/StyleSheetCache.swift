import Foundation

/// Books link the same style sheet from every chapter, so each is read and parsed once per layout.
nonisolated final class StyleSheetCache {
	private var sheets: [URL: StyleSheet] = [:]

	func sheet(at url: URL) -> StyleSheet {
		if let sheet = sheets[url] {
			return sheet
		}

		let css = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
		let sheet = StyleSheet(css: css)
		sheets[url] = sheet
		return sheet
	}
}
