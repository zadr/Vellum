import EPUBKit
import Foundation
import Zip

/// A downloaded EPUB, unzipped and parsed into the pieces the reader needs.
nonisolated struct ReaderBook: Sendable {
	/// The unzipped book.
	let root: URL
	/// Every document in reading order, as paths relative to `root`.
	let chapters: [String]
	let contents: [ReaderContentsEntry]

	/// Unzips the book if needed, then parses it. Runs off the main actor because both steps touch the disk.
	@concurrent
	static func open(_ file: URL, unpackingTo directory: URL) async throws -> ReaderBook {
		let fileManager = FileManager.default

		if !fileManager.fileExists(atPath: directory.appending(path: "META-INF/container.xml").path(percentEncoded: false)) {
			try? fileManager.removeItem(at: directory)
			try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
			Zip.addCustomFileExtension("epub")
			try Zip.unzipFile(file, destination: directory, overwrite: true, password: nil)
		}

		let document = try EPUBParser().parse(documentAt: directory)
		let root = normalized(directory)
		let contentDirectory = URL(filePath: document.contentDirectory.path(percentEncoded: false), directoryHint: .isDirectory)

		func relativePath(of url: URL) -> String? {
			let path = url.path(percentEncoded: false)
			let rootPath = root.path(percentEncoded: false)
			guard path.hasPrefix(rootPath) else { return nil }
			return String(path.dropFirst(rootPath.count).drop { $0 == "/" })
		}

		let chapters = document.spine.items.compactMap { item in
			document.manifest.items[item.idref]
				.flatMap { resolve($0.path, from: contentDirectory)?.url }
				.flatMap(relativePath)
		}

		// Table of contents links are relative to the table of contents file, not the package.
		var contentsDirectory = contentDirectory
		if let id = document.spine.toc, let path = document.manifest.items[id]?.path, let url = resolve(path, from: contentDirectory)?.url {
			contentsDirectory = url.deletingLastPathComponent()
		}

		var contents = [ReaderContentsEntry]()
		func add(childrenOf entry: EPUBTableOfContents, level: Int) {
			for child in entry.subTable ?? [] {
				if
					let item = child.item,
					let target = resolve(item, from: contentsDirectory),
					let path = relativePath(of: target.url),
					let chapter = chapters.firstIndex(of: path)
				{
					let title = child.label.trimmingCharacters(in: .whitespacesAndNewlines)
					contents.append(ReaderContentsEntry(id: contents.count, title: title, level: level, chapter: chapter, fragment: target.fragment))
				}
				add(childrenOf: child, level: level + 1)
			}
		}
		add(childrenOf: document.tableOfContents, level: 0)

		return ReaderBook(root: root, chapters: chapters, contents: contents)
	}

	func fileURL(forChapter chapter: Int) -> URL {
		root.appending(path: chapters[chapter])
	}

	/// The contents entry for the part of the book that chapter belongs to.
	func contentsEntry(forChapter chapter: Int) -> ReaderContentsEntry? {
		contents.last { $0.chapter <= chapter }
	}

	/// Resolves an `href` from the book, which may be percent-encoded and carry a `#fragment`.
	private static func resolve(_ href: String, from base: URL) -> (url: URL, fragment: String?)? {
		let parts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
		guard let url = URL(string: String(parts[0]), relativeTo: base) else { return nil }

		let fragment = parts.count > 1 ? String(parts[1]).removingPercentEncoding : nil
		return (normalized(url), fragment)
	}

	/// File URLs compare equal only when spelled the same way, so every path goes through here.
	private static func normalized(_ url: URL) -> URL {
		URL(filePath: url.absoluteURL.standardizedFileURL.path(percentEncoded: false))
	}
}
