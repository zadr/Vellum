import Foundation

/// Where every piece of a scrolling layout sits in the scroll, worked out from the layout's exact heights, so a
/// reading position and a scroll offset convert to each other exactly.
nonisolated struct ScrollMetrics: Sendable {
	/// The top of each piece, measured from the top of the scroll's content.
	let tops: [Double]
	let contentHeight: Double

	/// `chapterGap` is the space left above each chapter but the first.
	init(layout: BookLayout, chapterGap: Double) {
		var tops = [Double]()
		var y = 0.0
		for (index, page) in layout.pages.enumerated() {
			if index > 0, layout.isChapterStart(index) {
				y += chapterGap
			}
			tops.append(y)
			y += page.height
		}
		self.tops = tops
		contentHeight = y
	}

	/// The piece showing at a scroll offset: the last one starting at or above it.
	func piece(at y: Double) -> Int {
		var low = 0, high = tops.count - 1
		while low < high {
			let middle = (low + high + 1) / 2
			if tops[middle] <= y {
				low = middle
			} else {
				high = middle - 1
			}
		}
		return max(low, 0)
	}

	/// The pieces overlapping a stretch of the scroll.
	func pieces(from top: Double, to bottom: Double) -> Range<Int> {
		guard !tops.isEmpty else { return 0..<0 }
		return piece(at: top)..<min(piece(at: bottom) + 1, tops.count)
	}
}
