import Foundation

/// Books link the same style sheet from every chapter, so each is read and parsed once per layout.
/// Also holds the book's embedded fonts, which style sheets declare.
nonisolated final class StyleSheetCache {
	let fonts: BookFonts
	private var sheets: [URL: StyleSheet] = [:]

	init(bookRoot: URL) {
		fonts = BookFonts(bookRoot: bookRoot)
	}

	func sheet(at url: URL) -> StyleSheet {
		if let sheet = sheets[url] {
			return sheet
		}

		let css = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
		fonts.load(css: css, relativeTo: url)
		let sheet = StyleSheet(css: css)
		sheets[url] = sheet
		return sheet
	}
}
