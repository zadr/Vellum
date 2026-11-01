import CoreText

nonisolated enum ReaderFont: String, CaseIterable, Identifiable, Sendable {
	case charter
	case georgia
	case iowan
	case palatino
	case system

	var id: Self {
		self
	}

	var label: String {
		switch self {
		case .charter: "Charter"
		case .georgia: "Georgia"
		case .iowan: "Iowan"
		case .palatino: "Palatino"
		case .system: "San Francisco"
		}
	}

	func font(size: Double) -> CTFont {
		switch self {
		case .charter: CTFontCreateWithName("Charter-Roman" as CFString, size, nil)
		case .georgia: CTFontCreateWithName("Georgia" as CFString, size, nil)
		case .iowan: CTFontCreateWithName("IowanOldStyle-Roman" as CFString, size, nil)
		case .palatino: CTFontCreateWithName("Palatino-Roman" as CFString, size, nil)
		case .system: CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
		}
	}
}
