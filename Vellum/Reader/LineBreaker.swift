import Foundation

/// Chooses where a paragraph's lines break using Knuth and Plass's total-fit algorithm, which considers every
/// possible set of breaks and keeps the one where lines are most evenly full, rather than filling each line greedily.
nonisolated enum LineBreaker {
	struct Item {
		enum Kind {
			/// Something that can't be broken or stretched, like a word or part of one.
			case box
			/// Space between words: a break may happen here, and it can stretch or shrink.
			case glue
			/// A possible break that isn't a space, like a hyphenation point. Its width only counts if the line breaks here.
			case penalty
		}

		var kind: Kind
		var width: Double
		var stretch = 0.0
		var shrink = 0.0
		/// For penalties: the cost of breaking here. Negative infinity forces a break.
		var penalty = 0.0
		/// Breaks at flagged penalties, like hyphens, are discouraged from happening on consecutive lines.
		var isFlagged = false
	}

	private final class Node {
		let position: Int
		let line: Int
		let fitness: Int
		let totalWidth: Double
		let totalStretch: Double
		let totalShrink: Double
		let demerits: Double
		let previous: Node?

		init(position: Int, line: Int, fitness: Int, totalWidth: Double, totalStretch: Double, totalShrink: Double, demerits: Double, previous: Node?) {
			self.position = position
			self.line = line
			self.fitness = fitness
			self.totalWidth = totalWidth
			self.totalStretch = totalStretch
			self.totalShrink = totalShrink
			self.demerits = demerits
			self.previous = previous
		}
	}

	private static let linePenalty = 10.0
	private static let flaggedDemerits = 3000.0
	private static let fitnessDemerits = 3000.0

	/// The indices of the items to break at, ending with the last item, or `nil` if no breaks keep every line's
	/// spacing within `tolerance` (how many times its stretch a line may be stretched).
	static func breaks(_ items: [Item], lineWidth: (Int) -> Double, tolerance: Double) -> [Int]? {
		var active = [Node(position: -1, line: 0, fitness: 1, totalWidth: 0, totalStretch: 0, totalShrink: 0, demerits: 0, previous: nil)]
		var width = 0.0, stretch = 0.0, shrink = 0.0

		for (index, item) in items.enumerated() {
			switch item.kind {
			case .box:
				width += item.width
			case .glue:
				if index > 0, items[index - 1].kind == .box {
					considerBreak(at: index)
				}
				width += item.width
				stretch += item.stretch
				shrink += item.shrink
			case .penalty:
				if item.penalty < .infinity {
					considerBreak(at: index)
				}
			}

			if active.isEmpty {
				return nil
			}
		}

		guard let best = active.filter({ $0.position == items.count - 1 }).min(by: { $0.demerits < $1.demerits }) else { return nil }

		var positions = [Int]()
		var node: Node? = best
		while let current = node, current.position >= 0 {
			positions.append(current.position)
			node = current.previous
		}
		return positions.reversed()

		func considerBreak(at index: Int) {
			let item = items[index]
			let isForced = item.kind == .penalty && item.penalty == -.infinity
			var candidates: [Int: (demerits: Double, previous: Node)] = [:]
			var stillActive = [Node]()

			for node in active {
				let available = lineWidth(node.line)
				let length = width - node.totalWidth + (item.kind == .penalty ? item.width : 0)

				let ratio: Double
				if length < available {
					let lineStretch = stretch - node.totalStretch
					ratio = lineStretch > 0 ? (available - length) / lineStretch : .infinity
				} else if length > available {
					let lineShrink = shrink - node.totalShrink
					ratio = lineShrink > 0 ? (available - length) / lineShrink : -.infinity
				} else {
					ratio = 0
				}

				if ratio >= -1 && ratio <= tolerance {
					let badness = 100 * pow(abs(ratio), 3)
					let penalty = item.kind == .penalty ? item.penalty : 0
					var demerits = pow(linePenalty + badness, 2)
					if penalty > 0 {
						demerits += penalty * penalty
					} else if penalty > -.infinity {
						demerits -= penalty * penalty
					}

					if item.isFlagged, node.position >= 0, items[node.position].isFlagged {
						demerits += flaggedDemerits
					}

					let fitness = switch ratio {
					case ..<(-0.5): 0
					case ...0.5: 1
					case ...1: 2
					default: 3
					}
					if abs(fitness - node.fitness) > 1 {
						demerits += fitnessDemerits
					}

					demerits += node.demerits
					if demerits < candidates[fitness]?.demerits ?? .infinity {
						candidates[fitness] = (demerits, node)
					}
				}

				// A line that's already too full, or one ended by a forced break, can't be extended further.
				if ratio >= -1 && !isForced {
					stillActive.append(node)
				}
			}

			active = stillActive
			guard !candidates.isEmpty else { return }

			// The next line starts after any spaces following the break, so they don't count toward its width.
			var nextWidth = width, nextStretch = stretch, nextShrink = shrink
			for followingIndex in index..<items.count {
				let following = items[followingIndex]
				if following.kind == .box {
					break
				}
				if following.kind == .glue {
					nextWidth += following.width
					nextStretch += following.stretch
					nextShrink += following.shrink
				} else if following.penalty == -.infinity, followingIndex > index {
					break
				}
			}

			for (fitness, candidate) in candidates {
				active.append(Node(
					position: index,
					line: candidate.previous.line + 1,
					fitness: fitness,
					totalWidth: nextWidth,
					totalStretch: nextStretch,
					totalShrink: nextShrink,
					demerits: candidate.demerits,
					previous: candidate.previous
				))
			}
		}
	}
}
