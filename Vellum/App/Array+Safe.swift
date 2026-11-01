extension Array {
	/// The element at an index, or `nil` if the index is out of range.
	subscript(safe index: Index) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
