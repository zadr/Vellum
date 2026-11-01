import CoreText
import Foundation

/// Fonts a book embeds and names in `@font-face` rules, loaded from the book's files.
/// Fonts some publishers obfuscate, as the EPUB and Adobe specifications allow, are restored first.
nonisolated final class BookFonts: @unchecked Sendable {
	private struct Face: Hashable {
		var family: String
		var isBold: Bool
		var isItalic: Bool
	}

	private var faces: [Face: CTFontDescriptor] = [:]
	private var loadedSheets: Set<URL> = []
	/// Obfuscated font files, and the key for each: the IDPF method XORs 1040 bytes, Adobe's 1024.
	private let obfuscation: [URL: (key: [UInt8], length: Int)]

	init(bookRoot: URL) {
		obfuscation = Self.obfuscatedFonts(in: bookRoot)
	}

	/// Reads the `@font-face` rules in a style sheet, loading each font it names.
	func load(css: String, relativeTo base: URL) {
		guard !loadedSheets.contains(base) else { return }
		loadedSheets.insert(base)

		for match in css.matches(of: /@font-face\s*\{([^}]*)\}/) {
			let style = CSSStyle(declarations: String(match.output.1))
			guard
				let family = style.properties["font-family"].map(Self.normalizedFamily),
				let source = style.properties["src"],
				let path = source.firstMatch(of: /url\(\s*['"]?([^'")]+)['"]?\s*\)/)?.output.1,
				let url = URL(string: String(path), relativeTo: base)?.absoluteURL.standardizedFileURL,
				let descriptor = descriptor(at: url)
			else { continue }

			let face = Face(family: family, isBold: style.isBold ?? false, isItalic: style.isItalic ?? false)
			faces[face] = descriptor
		}
	}

	/// The first family in a `font-family` list that the book embeds, as a font of a size, or `nil` if none.
	func font(families: String, size: Double, isBold: Bool, isItalic: Bool) -> CTFont? {
		for family in families.split(separator: ",").map({ Self.normalizedFamily(String($0)) }) {
			let exact = faces[Face(family: family, isBold: isBold, isItalic: isItalic)]
			let fallback = faces[Face(family: family, isBold: false, isItalic: false)]
			guard let descriptor = exact ?? fallback else { continue }

			let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
			// Only the regular face is embedded, so synthesize the style the system way.
			if exact == nil, isBold || isItalic {
				var traits = CTFontSymbolicTraits()
				if isBold { traits.insert(.traitBold) }
				if isItalic { traits.insert(.traitItalic) }
				return CTFontCreateCopyWithSymbolicTraits(font, size, nil, traits, traits) ?? font
			}
			return font
		}
		return nil
	}

	private func descriptor(at url: URL) -> CTFontDescriptor? {
		guard var data = try? Data(contentsOf: url) else { return nil }

		if let (key, length) = obfuscation[url] {
			data.withUnsafeMutableBytes { bytes in
				for index in 0..<min(length, bytes.count) {
					bytes[index] ^= key[index % key.count]
				}
			}
		}

		return CTFontManagerCreateFontDescriptorFromData(data as CFData)
	}

	private static func normalizedFamily(_ family: String) -> String {
		family.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")).lowercased()
	}

	// MARK: Obfuscation

	private static func obfuscatedFonts(in root: URL) -> [URL: (key: [UInt8], length: Int)] {
		guard let encryption = try? String(contentsOf: root.appending(path: "META-INF/encryption.xml"), encoding: .utf8) else { return [:] }

		var fonts = [URL: (key: [UInt8], length: Int)]()
		for match in encryption.matches(of: /(?s)<(?:\w+:)?EncryptedData.*?Algorithm="([^"]+)".*?URI="([^"]+)".*?<\/(?:\w+:)?EncryptedData>/) {
			let algorithm = String(match.output.1)
			guard let path = String(match.output.2).removingPercentEncoding else { continue }
			let url = root.appending(path: path).standardizedFileURL

			if algorithm.contains("idpf.org/2008/embedding"), let key = idpfKey(root: root) {
				fonts[url] = (key, 1040)
			} else if algorithm.contains("ns.adobe.com/pdf/enc#RC"), let key = adobeKey(root: root) {
				fonts[url] = (key, 1024)
			}
		}
		return fonts
	}

	/// The package's unique identifier, as the obfuscation key is made from it.
	private static func uniqueIdentifier(root: URL) -> String? {
		guard
			let container = try? String(contentsOf: root.appending(path: "META-INF/container.xml"), encoding: .utf8),
			let opfPath = container.firstMatch(of: /full-path="([^"]+)"/)?.output.1,
			let opf = try? String(contentsOf: root.appending(path: String(opfPath)), encoding: .utf8),
			let idName = opf.firstMatch(of: /unique-identifier="([^"]+)"/)?.output.1
		else { return nil }

		let pattern = try? Regex("<(?:\\w+:)?identifier[^>]*id=\"\(NSRegularExpression.escapedPattern(for: String(idName)))\"[^>]*>([^<]+)<")
		guard let pattern, let match = opf.firstMatch(of: pattern), let identifier = match.output[1].substring else { return nil }
		return String(identifier).trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// The IDPF key is the SHA-1 of the unique identifier with whitespace removed.
	private static func idpfKey(root: URL) -> [UInt8]? {
		guard let identifier = uniqueIdentifier(root: root) else { return nil }
		return SHA1.hash(Array(identifier.filter { !$0.isWhitespace }.utf8))
	}

	/// Adobe's key is the 16 bytes of the identifier's UUID.
	private static func adobeKey(root: URL) -> [UInt8]? {
		guard let identifier = uniqueIdentifier(root: root) else { return nil }
		let hex = identifier.lowercased().replacing("urn:uuid:", with: "").filter(\.isHexDigit)
		guard hex.count == 32 else { return nil }

		var bytes = [UInt8]()
		var index = hex.startIndex
		while index < hex.endIndex {
			let next = hex.index(index, offsetBy: 2)
			bytes.append(UInt8(hex[index..<next], radix: 16) ?? 0)
			index = next
		}
		return bytes
	}
}
