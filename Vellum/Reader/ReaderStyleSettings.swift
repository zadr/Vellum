import Foundation

/// Which parts of a book's own styling the reader follows. Everything follows the book unless overridden.
nonisolated struct ReaderStyleSettings: Equatable, Sendable {
	enum Justification: String, CaseIterable, Identifiable, Sendable {
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
	/// Use the book's text and background colors. Off draws everything in the theme's colors.
	var bookColors = true

	init() {}

	/// The switches, by the names they're stored under.
	private static var switches: [(String, WritableKeyPath<Self, Bool>)] { [
		("bookLineHeight", \.bookLineHeight), ("bookParagraphSpacing", \.bookParagraphSpacing),
		("bookTextSizes", \.bookTextSizes), ("bookDropCaps", \.bookDropCaps), ("bookIndents", \.bookIndents),
		("bookMargins", \.bookMargins), ("bookTextEffects", \.bookTextEffects), ("bookFonts", \.bookFonts),
		("bookBorders", \.bookBorders), ("bookTables", \.bookTables), ("bookPageBreaks", \.bookPageBreaks), ("bookColors", \.bookColors),
	] }
}

/// Stored in `@AppStorage` as a JSON object. Not `Codable`: a type that's both `Codable` and `RawRepresentable`
/// encodes itself through `rawValue`, which loops forever. Settings missing from the stored value keep their defaults.
extension ReaderStyleSettings: RawRepresentable {
	init?(rawValue: String) {
		guard let object = try? JSONSerialization.jsonObject(with: Data(rawValue.utf8)) as? [String: Any] else { return nil }

		self.init()
		for (name, keyPath) in Self.switches {
			if let value = object[name] as? Bool {
				self[keyPath: keyPath] = value
			}
		}
		if let value = (object["justification"] as? String).flatMap(Justification.init) {
			justification = value
		}
	}

	var rawValue: String {
		var object: [String: Any] = ["justification": justification.rawValue]
		for (name, keyPath) in Self.switches {
			object[name] = self[keyPath: keyPath]
		}
		let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
		return String(decoding: data, as: UTF8.self)
	}
}
