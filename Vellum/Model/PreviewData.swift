import Foundation
// Sample data for SwiftUI previews.

extension Book {
	static let preview: Book = {
		let json = """
		{
			"title": "Fantastic Mr. Fox",
			"key": "/books/OL7353617M",
			"authors": [{"key": "/authors/OL34184A"}],
			"publish_date": "October 1, 1988",
			"publishers": ["Puffin"],
			"covers": [8739161],
			"number_of_pages": 96,
			"isbn_13": ["9780140328721"],
			"subjects": ["Foxes", "Farmers", "Juvenile fiction"]
		}
		"""

		do {
			return try Book.create(with: Data(json.utf8))
		} catch {
			fatalError("Preview book JSON is invalid: \(error)")
		}
	}()
}

extension Entry {
	static let preview = Entry(isbn: ISBN("9780140328721"), book: .preview, authors: ["Roald Dahl"], rating: 4, notes: "Read aloud with the kids.")
}
