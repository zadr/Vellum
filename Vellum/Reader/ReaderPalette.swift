import SwiftUI

/// The colors a page is drawn with.
struct ReaderPalette: Equatable {
	static let light = ReaderPalette(background: 0xFFFFFF, text: 0x1C1C1E, isDark: false)
	static let paper = ReaderPalette(background: 0xFAF7F0, text: 0x2B2A28, isDark: false)
	static let sepia = ReaderPalette(background: 0xF4ECD8, text: 0x5B4636, isDark: false)
	static let sage = ReaderPalette(background: 0xE3EBDD, text: 0x2F3B2A, isDark: false)
	static let quiet = ReaderPalette(background: 0x4A4A4D, text: 0xD9D9DC, isDark: true)
	static let dark = ReaderPalette(background: 0x121212, text: 0xDADADA, isDark: true)
	/// True black, so OLED screens switch the background pixels off.
	static let black = ReaderPalette(background: 0x000000, text: 0xB4B4B4, isDark: true)

	let background: Int
	let text: Int
	let isDark: Bool

	var backgroundColor: Color {
		Color(cgColor: Self.cgColor(background))
	}

	var textColor: CGColor {
		Self.cgColor(text)
	}

	var colorScheme: ColorScheme {
		isDark ? .dark : .light
	}

	private static func cgColor(_ hex: Int) -> CGColor {
		CGColor(srgbRed: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, alpha: 1)
	}
}
