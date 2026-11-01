import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable {
	case automatic
	case light
	case paper
	case sepia
	case sage
	case quiet
	case dark
	case black

	var id: Self {
		self
	}

	var label: String {
		switch self {
		case .automatic: "Match System"
		case .light: "Light"
		case .paper: "Paper"
		case .sepia: "Sepia"
		case .sage: "Sage"
		case .quiet: "Quiet"
		case .dark: "Dark"
		case .black: "Black"
		}
	}

	/// For places with little room, like under a theme swatch.
	var shortLabel: String {
		self == .automatic ? "Auto" : label
	}

	func palette(for colorScheme: ColorScheme) -> ReaderPalette {
		switch self {
		case .automatic: colorScheme == .dark ? .dark : .light
		case .light: .light
		case .paper: .paper
		case .sepia: .sepia
		case .sage: .sage
		case .quiet: .quiet
		case .dark: .dark
		case .black: .black
		}
	}
}
