// Draws Vellum's app icon (light, dark, and tinted variants).
//
// Usage: swift Tools/GenerateAppIcon.swift Vellum/Assets.xcassets/AppIcon.appiconset

import AppKit
import SwiftUI

struct Palette {
	var background: [Color]
	var highlight: Color
	var cover: [Color]
	var spine: Color
	var pages: Color
	var pageLine: Color
	var ribbon: Color
	var face: Color
	var blush: Color
	var sparkle: Color
	var shadow: Color
}

func rgb(_ hex: UInt32) -> Color {
	Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

let light = Palette(
	background: [rgb(0xFF5CA8), rgb(0xB13FE0), rgb(0x3A1585)],
	highlight: .white,
	cover: [rgb(0xFFFFFF), rgb(0xF3E6FF)],
	spine: rgb(0x7B2FD0),
	pages: rgb(0xFFF1D6),
	pageLine: rgb(0xE8C9A0),
	ribbon: rgb(0xFF3D8B),
	face: rgb(0x2E1046),
	blush: rgb(0xFF7AAE),
	sparkle: rgb(0xFFF4B8),
	shadow: rgb(0x1E0640)
)

let dark = Palette(
	background: [rgb(0x8E2A8F), rgb(0x4A1680), rgb(0x12052B)],
	highlight: rgb(0xE6B3FF),
	cover: [rgb(0xF4EAFF), rgb(0xDCC7F2)],
	spine: rgb(0x9A55E8),
	pages: rgb(0xF2E2C6),
	pageLine: rgb(0xCFAE85),
	ribbon: rgb(0xFF4F98),
	face: rgb(0x2E1046),
	blush: rgb(0xFF7AAE),
	sparkle: rgb(0xFFE89A),
	shadow: .black
)

let tinted = Palette(
	background: [.black, .black],
	highlight: Color(white: 0.4),
	cover: [Color(white: 1), Color(white: 0.9)],
	spine: Color(white: 0.55),
	pages: Color(white: 0.75),
	pageLine: Color(white: 0.55),
	ribbon: Color(white: 0.65),
	face: Color(white: 0.12),
	blush: Color(white: 0.7),
	sparkle: Color(white: 0.9),
	shadow: .black
)

func sparkle(at c: CGPoint, size s: Double) -> Path {
	var p = Path()
	p.move(to: CGPoint(x: c.x, y: c.y - s))
	p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: c)
	p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: c)
	p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: c)
	p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: c)
	p.closeSubpath()
	return p
}

func ribbon() -> Path {
	// Hangs out of the bottom of the book, with a notched tail.
	var p = Path()
	p.move(to: CGPoint(x: 600, y: 760))
	p.addLine(to: CGPoint(x: 676, y: 760))
	p.addLine(to: CGPoint(x: 676, y: 905))
	p.addLine(to: CGPoint(x: 638, y: 872))
	p.addLine(to: CGPoint(x: 600, y: 905))
	p.closeSubpath()
	return p
}

struct Icon: View {
	let palette: Palette

	var body: some View {
		Canvas { ctx, size in
			let full = CGRect(origin: .zero, size: size)

			ctx.fill(Path(full), with: .linearGradient(Gradient(colors: palette.background), startPoint: .zero, endPoint: CGPoint(x: 700, y: 1024)))
			ctx.fill(Path(ellipseIn: CGRect(x: -200, y: -260, width: 900, height: 800)), with: .radialGradient(
				Gradient(colors: [palette.highlight.opacity(0.35), palette.highlight.opacity(0)]),
				center: CGPoint(x: 250, y: 140), startRadius: 0, endRadius: 450))

			for (point, size) in [(CGPoint(x: 190, y: 240), 52.0), (CGPoint(x: 840, y: 200), 38.0), (CGPoint(x: 860, y: 610), 30.0), (CGPoint(x: 165, y: 700), 26.0), (CGPoint(x: 770, y: 360), 18.0)] {
				ctx.fill(sparkle(at: point, size: size), with: .color(palette.sparkle))
			}

			// Soft shadow the book sits on.
			ctx.drawLayer { layer in
				layer.addFilter(.blur(radius: 30))
				layer.fill(Path(ellipseIn: CGRect(x: 290, y: 820, width: 460, height: 90)), with: .color(palette.shadow.opacity(0.45)))
			}

			// The book leans a little, which makes it feel more alive.
			ctx.translateBy(x: 512, y: 530)
			ctx.rotate(by: .degrees(-7))
			ctx.translateBy(x: -512, y: -530)

			let cover = CGRect(x: 272, y: 220, width: 470, height: 600)

			ctx.fill(ribbon(), with: .color(palette.ribbon))

			// Page block peeking out on the right and bottom.
			let pages = cover.offsetBy(dx: 26, dy: 22)
			ctx.fill(Path(roundedRect: pages, cornerRadius: 64), with: .color(palette.pages))
			for i in 0..<4 {
				var line = Path()
				let y = pages.minY + 140 + Double(i) * 105
				line.move(to: CGPoint(x: pages.maxX - 18, y: y))
				line.addLine(to: CGPoint(x: pages.maxX - 6, y: y))
				ctx.stroke(line, with: .color(palette.pageLine), style: StrokeStyle(lineWidth: 8, lineCap: .round))
			}

			ctx.drawLayer { layer in
				layer.addFilter(.shadow(color: palette.shadow.opacity(0.3), radius: 18, x: 6, y: 10))
				layer.fill(Path(roundedRect: cover, cornerRadius: 64), with: .linearGradient(
					Gradient(colors: palette.cover), startPoint: CGPoint(x: cover.minX, y: cover.minY), endPoint: CGPoint(x: cover.maxX, y: cover.maxY)))
			}

			// Spine.
			var spine = Path(roundedRect: CGRect(x: cover.minX, y: cover.minY, width: 128, height: cover.height), cornerRadii: RectangleCornerRadii(topLeading: 64, bottomLeading: 64))
			spine = spine.intersection(Path(roundedRect: cover, cornerRadius: 64))
			ctx.fill(spine, with: .color(palette.spine))
			for y in [cover.minY + 90, cover.maxY - 90] {
				var band = Path()
				band.move(to: CGPoint(x: cover.minX + 28, y: y))
				band.addLine(to: CGPoint(x: cover.minX + 100, y: y))
				ctx.stroke(band, with: .color(palette.cover[0].opacity(0.5)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
			}

			// Glossy shine on the cover.
			var shine = Path()
			shine.move(to: CGPoint(x: 445, y: 270))
			shine.addLine(to: CGPoint(x: 690, y: 270))
			ctx.stroke(shine, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
			ctx.fill(Path(ellipseIn: CGRect(x: 703, y: 261, width: 18, height: 18)), with: .color(.white.opacity(0.9)))

			// Face, centered on the part of the cover right of the spine.
			let faceX = cover.minX + 128 + (cover.width - 128) / 2
			for dx in [-82.0, 82.0] {
				let eye = CGRect(x: faceX + dx - 34, y: 440, width: 68, height: 92)
				ctx.fill(Path(ellipseIn: eye), with: .color(palette.face))
				ctx.fill(Path(ellipseIn: CGRect(x: eye.minX + 14, y: eye.minY + 14, width: 28, height: 32)), with: .color(.white))
				ctx.fill(Path(ellipseIn: CGRect(x: eye.minX + 40, y: eye.minY + 56, width: 13, height: 13)), with: .color(.white.opacity(0.85)))
			}
			for dx in [-140.0, 140.0] {
				ctx.fill(Path(ellipseIn: CGRect(x: faceX + dx - 42, y: 548, width: 84, height: 44)), with: .color(palette.blush.opacity(0.6)))
			}
			var mouth = Path()
			mouth.move(to: CGPoint(x: faceX - 36, y: 565))
			mouth.addQuadCurve(to: CGPoint(x: faceX + 36, y: 565), control: CGPoint(x: faceX, y: 612))
			ctx.stroke(mouth, with: .color(palette.face), style: StrokeStyle(lineWidth: 15, lineCap: .round))
		}
		.frame(width: 1024, height: 1024)
	}
}

@MainActor
func render(_ palette: Palette, to path: String) {
	let renderer = ImageRenderer(content: Icon(palette: palette))
	renderer.scale = 1
	guard let cg = renderer.cgImage else { fatalError("render failed") }

	// Flatten onto an opaque context so the PNG has no alpha channel.
	let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
		space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
	ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
	let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
	try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments[1]
MainActor.assumeIsolated {
	render(light, to: "\(out)/AppIcon.png")
	render(dark, to: "\(out)/AppIcon-Dark.png")
	render(tinted, to: "\(out)/AppIcon-Tinted.png")
}
