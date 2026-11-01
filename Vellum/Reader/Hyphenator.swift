import CoreFoundation
import Foundation

/// Finds where words may be hyphenated. Books repeat the same words constantly, so each word is only looked up once.
nonisolated final class Hyphenator {
	/// Books don't reliably say what language they're in, and most of the library is English.
	private let locale = CFLocaleCreate(nil, CFLocaleIdentifier("en_US" as CFString))
	private lazy var isAvailable = CFStringIsHyphenationAvailableForLocale(locale)
	/// Hyphenation points for each word, counted from the word's start.
	private var cache: [String: [Int]] = [:]

	/// Where a word may be hyphenated, keeping at least two letters on each side.
	func points(in string: NSString, word: Range<Int>) -> [Int] {
		guard word.count >= 5, isAvailable else { return [] }

		let text = string.substring(with: NSRange(location: word.lowerBound, length: word.count))
		if let points = cache[text] {
			return points.map { $0 + word.lowerBound }
		}

		let wordString = text as NSString
		var points = [Int]()
		var before = wordString.length - 2
		while before > 1 {
			let location = CFStringGetHyphenationLocationBeforeIndex(wordString as CFString, before, CFRange(location: 0, length: wordString.length), 0, locale, nil)
			guard location != kCFNotFound, location > 1, location <= before else { break }

			points.append(location)
			before = location - 1
		}

		points.reverse()
		cache[text] = points
		return points.map { $0 + word.lowerBound }
	}
}
