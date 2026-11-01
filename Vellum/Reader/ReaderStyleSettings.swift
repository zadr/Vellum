import Foundation

/// Which parts of a book's own styling the reader follows. Everything follows the book unless overridden.
nonisolated struct ReaderStyleSettings: Codable, Equatable, Sendable {
	enum Justification: String, Codable, CaseIterable, Identifiable, Sendable {
		case book
		case justified
		case ragged

		var id: Self {
			self
		}

		var label: String {
			switch self {
			case .book: "Book"
			case .justified: "Justified"
			case .ragged: "Ragged"
			}
		}
	}

	/// Use the book's line heights instead of the line height setting.
	var bookLineHeight = true
	/// Use the book's paragraph margins instead of the paragraph spacing setting.
	var bookParagraphSpacing = true
	var justification = Justification.book
	/// Follow the book's relative text sizes. Off evens out small differences in body text.
	var bookTextSizes = true
	var bookDropCaps = true

	private enum CodingKeys: String, CodingKey {
		case bookLineHeight, bookParagraphSpacing, justification, bookTextSizes, bookDropCaps
	}

	init() {}

	init(from decoder: any Decoder) throws {
		// Settings added later decode to their defaults rather than failing the whole value.
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let defaults = ReaderStyleSettings()
		bookLineHeight = try container.decodeIfPresent(Bool.self, forKey: .bookLineHeight) ?? defaults.bookLineHeight
		bookParagraphSpacing = try container.decodeIfPresent(Bool.self, forKey: .bookParagraphSpacing) ?? defaults.bookParagraphSpacing
		justification = try container.decodeIfPresent(Justification.self, forKey: .justification) ?? defaults.justification
		bookTextSizes = try container.decodeIfPresent(Bool.self, forKey: .bookTextSizes) ?? defaults.bookTextSizes
		bookDropCaps = try container.decodeIfPresent(Bool.self, forKey: .bookDropCaps) ?? defaults.bookDropCaps
	}
}

/// Stored in `@AppStorage` as JSON.
extension ReaderStyleSettings: RawRepresentable {
	init?(rawValue: String) {
		guard let value = try? JSONDecoder().decode(Self.self, from: Data(rawValue.utf8)) else { return nil }
		self = value
	}

	var rawValue: String {
		(try? String(decoding: JSONEncoder().encode(self), as: UTF8.self)) ?? "{}"
	}
}
