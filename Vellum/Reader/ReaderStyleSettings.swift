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
	/// Indent the first lines of paragraphs as the book does.
	var bookIndents = true
	/// Inset blocks like quotes, letters, and poems by the book's left and right margins.
	var bookMargins = true
	/// Small caps, capitalization, letter spacing, and text the book's styles add.
	var bookTextEffects = true
	/// Use the fonts the book chooses or embeds, where it chooses one, instead of the reader's font.
	var bookFonts = true
	/// Draw the book's borders and rules.
	var bookBorders = true
	/// Lay tables out in columns. Off lists each cell on its own line.
	var bookTables = true
	/// Start a new page where the book asks, and keep lines together as it asks.
	var bookPageBreaks = true

	private enum CodingKeys: String, CodingKey {
		case bookLineHeight, bookParagraphSpacing, justification, bookTextSizes, bookDropCaps, bookIndents, bookMargins, bookTextEffects, bookFonts, bookBorders, bookTables, bookPageBreaks
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
		bookIndents = try container.decodeIfPresent(Bool.self, forKey: .bookIndents) ?? defaults.bookIndents
		bookMargins = try container.decodeIfPresent(Bool.self, forKey: .bookMargins) ?? defaults.bookMargins
		bookTextEffects = try container.decodeIfPresent(Bool.self, forKey: .bookTextEffects) ?? defaults.bookTextEffects
		bookFonts = try container.decodeIfPresent(Bool.self, forKey: .bookFonts) ?? defaults.bookFonts
		bookBorders = try container.decodeIfPresent(Bool.self, forKey: .bookBorders) ?? defaults.bookBorders
		bookTables = try container.decodeIfPresent(Bool.self, forKey: .bookTables) ?? defaults.bookTables
		bookPageBreaks = try container.decodeIfPresent(Bool.self, forKey: .bookPageBreaks) ?? defaults.bookPageBreaks
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
