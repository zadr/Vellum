import CoreGraphics
import Foundation

/// Books link the same style sheet from every chapter, so each is read and parsed once per layout.
/// Also holds the book's embedded fonts, which style sheets declare.
nonisolated final class StyleSheetCache {
	let fonts: BookFonts
	/// The page size in CSS pixels, which `@media` rules are matched against.
	let viewport: CGSize
	private var sheets: [URL: StyleSheet] = [:]

	init(bookRoot: URL, viewport: CGSize = CGSize(width: 390, height: 844)) {
		fonts = BookFonts(bookRoot: bookRoot)
		self.viewport = viewport
	}

	func sheet(at url: URL) -> StyleSheet {
		if let sheet = sheets[url] {
			return sheet
		}

		let css = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
		fonts.load(css: css, relativeTo: url)
		let sheet = StyleSheet(css: css, viewport: viewport)
		sheets[url] = sheet
		return sheet
	}
}
