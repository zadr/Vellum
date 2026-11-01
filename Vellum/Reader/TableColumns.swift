import Foundation

/// The columns of a table, shared by its rows. Each row records how wide its cells' text is, and the widths
/// are settled once the table is complete.
nonisolated final class TableColumns: @unchecked Sendable {
	/// The widest text in each column, in characters, as a measure of how much room it needs.
	private(set) var contentLengths: [Int] = []

	func addRow(cellLengths: [Int]) {
		for (index, length) in cellLengths.enumerated() {
			if index < contentLengths.count {
				contentLengths[index] = max(contentLengths[index], length)
			} else {
				contentLengths.append(length)
			}
		}
	}

	/// Where each column starts and how wide it is, sharing the width by how much text each column holds.
	/// Short columns get what they need; the rest is shared among the longer ones.
	func columns(width: Double, gap: Double) -> [(x: Double, width: Double)] {
		guard !contentLengths.isEmpty else { return [] }

		let available = max(width - gap * Double(contentLengths.count - 1), 1)
		let weights = contentLengths.map { Double(max($0, 1)).squareRoot() }
		let total = weights.reduce(0, +)

		var x = 0.0
		return weights.map { weight in
			let columnWidth = available * weight / total
			defer { x += columnWidth + gap }
			return (x, columnWidth)
		}
	}
}
