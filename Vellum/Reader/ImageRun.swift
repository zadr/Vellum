import CoreGraphics
import CoreText

/// An image placed in the text. Core Text reserves its space; the page draws it there afterwards.
nonisolated final class ImageRun: @unchecked Sendable {
	let image: CGImage
	let size: CGSize

	init(image: CGImage, size: CGSize) {
		self.image = image
		self.size = size
	}

	/// Tells Core Text how much room the image needs. The image sits on the baseline, so it has no descent.
	func makeRunDelegate() -> CTRunDelegate? {
		var callbacks = CTRunDelegateCallbacks(
			version: kCTRunDelegateCurrentVersion,
			dealloc: { reference in
				Unmanaged<ImageRun>.fromOpaque(reference).release()
			},
			getAscent: { reference in
				Unmanaged<ImageRun>.fromOpaque(reference).takeUnretainedValue().size.height
			},
			getDescent: { _ in
				0
			},
			getWidth: { reference in
				Unmanaged<ImageRun>.fromOpaque(reference).takeUnretainedValue().size.width
			}
		)

		return CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(self).toOpaque())
	}
}
