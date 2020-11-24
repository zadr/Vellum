import Foundation

struct API {
	func request(isbn: String, completion: @escaping (Result<Book, Error>) -> Void) -> URLSessionDataTask {
		precondition(isbn.count == 13)

		let url = "https://openlibrary.org/isbn/\(isbn).json"
		print(url)
		return URLSession.shared.dataTask(with: URL(string: url)!) { data, response, error in
			guard let data = data else {
				if let error = error {
					completion(.failure(error))
				}

				return
			}

			do {
				let book: Book = try Book.create(with: data)
				completion(.success(book))
			} catch let error {
				completion(.failure(error))
			}
		}
	}
}
