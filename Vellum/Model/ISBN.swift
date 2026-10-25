import Foundation

/// A validated ISBN, always stored in its 13-digit form.
struct ISBN: Hashable, Codable, CustomStringConvertible {
	let digits: String

	/// Parses user input or a scanned barcode, accepting ISBN-10 or ISBN-13 with or without hyphens and spaces.
	init?(_ input: String) {
		let cleaned = input.uppercased().filter { $0.isNumber || $0 == "X" }

		switch cleaned.count {
		case 13 where Self.isValid13(cleaned):
			digits = cleaned
		case 10 where Self.isValid10(cleaned):
			digits = Self.convert10To13(cleaned)
		default:
			return nil
		}
	}

	var description: String {
		digits
	}

	/// Explains why some input isn't a valid ISBN, or returns `nil` while the input could still become one.
	static func problem(with input: String) -> String? {
		let cleaned = input.uppercased().filter { $0.isNumber || $0 == "X" }

		return switch cleaned.count {
		case 0..<10, 11, 12:
			nil
		case 10, 13:
			ISBN(cleaned) == nil ? "That ISBN doesn’t look right. Check the digits and try again." : nil
		default:
			"ISBNs are 10 or 13 digits long."
		}
	}

	private static func isValid13(_ value: String) -> Bool {
		guard value.hasPrefix("978") || value.hasPrefix("979") else { return false }

		let numbers = value.compactMap(\.wholeNumberValue)
		guard numbers.count == 13 else { return false }

		let sum = numbers.enumerated().reduce(0) { total, pair in
			total + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
		}
		return sum.isMultiple(of: 10)
	}

	private static func isValid10(_ value: String) -> Bool {
		let characters = Array(value)
		var sum = 0

		for (index, character) in characters.enumerated() {
			let number: Int
			if character == "X" && index == 9 {
				number = 10
			} else if let digit = character.wholeNumberValue {
				number = digit
			} else {
				return false
			}

			sum += number * (10 - index)
		}

		return sum.isMultiple(of: 11)
	}

	private static func convert10To13(_ value: String) -> String {
		let body = "978" + value.prefix(9)
		let sum = body.compactMap(\.wholeNumberValue).enumerated().reduce(0) { total, pair in
			total + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
		}
		return body + String((10 - sum % 10) % 10)
	}
}
