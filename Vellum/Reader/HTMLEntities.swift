import Foundation

/// XML only knows five named entities, but books use HTML's. These are swapped for characters before parsing.
nonisolated enum HTMLEntities {
	private static let characters: [String: String] = [
		"nbsp": "\u{00A0}", "ensp": "\u{2002}", "emsp": "\u{2003}", "thinsp": "\u{2009}", "shy": "\u{00AD}",
		"zwnj": "\u{200C}", "zwj": "\u{200D}",
		"ndash": "–", "mdash": "—", "hellip": "…", "bull": "•", "middot": "·", "prime": "′", "Prime": "″",
		"lsquo": "‘", "rsquo": "’", "sbquo": "‚", "ldquo": "“", "rdquo": "”", "bdquo": "„",
		"laquo": "«", "raquo": "»", "lsaquo": "‹", "rsaquo": "›",
		"copy": "©", "reg": "®", "trade": "™", "sect": "§", "para": "¶", "dagger": "†", "Dagger": "‡",
		"deg": "°", "plusmn": "±", "times": "×", "divide": "÷", "frac12": "½", "frac14": "¼", "frac34": "¾",
		"sup1": "¹", "sup2": "²", "sup3": "³", "micro": "µ", "minus": "−",
		"cent": "¢", "pound": "£", "euro": "€", "yen": "¥", "curren": "¤",
		"iexcl": "¡", "iquest": "¿", "ordf": "ª", "ordm": "º", "not": "¬", "macr": "¯", "acute": "´", "cedil": "¸", "uml": "¨",
		"larr": "←", "rarr": "→", "uarr": "↑", "darr": "↓", "harr": "↔",
		"Agrave": "À", "Aacute": "Á", "Acirc": "Â", "Atilde": "Ã", "Auml": "Ä", "Aring": "Å", "AElig": "Æ", "Ccedil": "Ç",
		"Egrave": "È", "Eacute": "É", "Ecirc": "Ê", "Euml": "Ë", "Igrave": "Ì", "Iacute": "Í", "Icirc": "Î", "Iuml": "Ï",
		"ETH": "Ð", "Ntilde": "Ñ", "Ograve": "Ò", "Oacute": "Ó", "Ocirc": "Ô", "Otilde": "Õ", "Ouml": "Ö", "Oslash": "Ø",
		"Ugrave": "Ù", "Uacute": "Ú", "Ucirc": "Û", "Uuml": "Ü", "Yacute": "Ý", "THORN": "Þ", "szlig": "ß",
		"agrave": "à", "aacute": "á", "acirc": "â", "atilde": "ã", "auml": "ä", "aring": "å", "aelig": "æ", "ccedil": "ç",
		"egrave": "è", "eacute": "é", "ecirc": "ê", "euml": "ë", "igrave": "ì", "iacute": "í", "icirc": "î", "iuml": "ï",
		"eth": "ð", "ntilde": "ñ", "ograve": "ò", "oacute": "ó", "ocirc": "ô", "otilde": "õ", "ouml": "ö", "oslash": "ø",
		"ugrave": "ù", "uacute": "ú", "ucirc": "û", "uuml": "ü", "yacute": "ý", "thorn": "þ", "yuml": "ÿ",
		"OElig": "Œ", "oelig": "œ", "Scaron": "Š", "scaron": "š", "Yuml": "Ÿ", "fnof": "ƒ",
	]

	private static let xmlEntities: Set<String> = ["amp", "lt", "gt", "quot", "apos"]

	/// Replaces HTML's named entities so an XML parser can read the document.
	static func xmlCompatible(_ markup: String) -> String {
		// Most chapters only use XML's own entities, if any, so skip the work when there's nothing to replace.
		var scanner = markup.utf8[...]
		var needsReplacing = false
		while let ampersand = scanner.firstIndex(of: UInt8(ascii: "&")) {
			let rest = markup.utf8[markup.utf8.index(after: ampersand)...]
			let name = rest.prefix { ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) }
			if !name.isEmpty, rest.dropFirst(name.count).first == UInt8(ascii: ";"), !xmlEntities.contains(String(decoding: name, as: UTF8.self)) {
				needsReplacing = true
				break
			}
			scanner = rest
		}
		guard needsReplacing else { return markup }

		return markup.replacing(/&([A-Za-z][A-Za-z0-9]*);/) { match in
			let name = String(match.output.1)
			if xmlEntities.contains(name) {
				return String(match.output.0)
			}
			return characters[name] ?? ""
		}
	}

	/// Replaces every entity with its character, for text that isn't going through an XML parser.
	static func decoded(_ text: String) -> String {
		text.replacing(/&(#x[0-9A-Fa-f]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);/) { match in
			let name = match.output.1
			if name.hasPrefix("#x"), let value = UInt32(name.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(value) {
				return String(Character(scalar))
			}
			if name.hasPrefix("#"), let value = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(value) {
				return String(Character(scalar))
			}

			let standard = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"]
			return standard[String(name)] ?? characters[String(name)] ?? ""
		}
	}
}
