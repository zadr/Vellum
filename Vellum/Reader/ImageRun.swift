import CoreGraphics
import CoreText
import Foundation

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

	/// The images in a line, with how far along the line each starts.
	static func images(in line: CTLine) -> [(run: ImageRun, offset: Double)] {
		(CTLineGetGlyphRuns(line) as? [CTRun] ?? []).compactMap { run in
			let attributes = CTRunGetAttributes(run) as NSDictionary
			guard let image = attributes[ChapterConverter.imageAttribute.rawValue] as? ImageRun else { return nil }
			return (image, CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil))
		}
	}

	/// Draws a line's images, which Core Text leaves as empty space, on the baseline at `origin`.
	static func draw(in line: CTLine, at origin: CGPoint, context: CGContext) {
		for image in images(in: line) {
			context.draw(image.run.image, in: CGRect(x: origin.x + image.offset, y: origin.y, width: image.run.size.width, height: image.run.size.height))
		}
	}
}
