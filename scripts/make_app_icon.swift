// Placeholder app icon, generated from the design kit's own tokens
// (Theme.swift: ink/fridge/paper + the pink palette slot). The fridge door
// with its magnet dot and one sticky note — the home screen's identity at
// icon scale. NEEDS-VISUAL-REVIEW: replaceable any build, zero art debt.
//
//   swift scripts/make_app_icon.swift Moody/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
// noneSkipLast ⇒ opaque bitmap — the 1024 marketing icon must carry no alpha.
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("no context") }

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255, alpha])!
}

let ink = rgb(0x2A2440)
let inkShadow = rgb(0x2A2440, 0.13)   // the kit's zero-blur hard shadow
let fridge = rgb(0xEFEBE2)
let paper = rgb(0xFFFFFF)
let pink = rgb(0xFF7BAC)
let pinkTint = rgb(0xFDE7F0)

// Visual (y-down) → CG (y-up) rect helper.
func vrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: CGFloat(size) - y - h, width: w, height: h)
}

func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func fillStroke(_ path: CGPath, fill: CGColor, stroke: CGColor?, width: CGFloat) {
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
    if let stroke {
        ctx.addPath(path)
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }
}

// 1. The fridge wall.
ctx.setFillColor(fridge)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// 2. The door: paper card, ink border, zero-blur hard shadow (down-right).
let door = vrect(176, 260, 672, 616)
let doorRadius: CGFloat = 96
fillStroke(rounded(door.offsetBy(dx: 40, dy: -40), doorRadius),
           fill: inkShadow, stroke: nil, width: 0)
fillStroke(rounded(door, doorRadius), fill: paper, stroke: ink, width: 20)

// 3. One sticky note inside the door, tilted like the home screen's.
ctx.saveGState()
let stickyCenter = CGPoint(x: 512, y: CGFloat(size) - 640)   // visual (512, 640)
ctx.translateBy(x: stickyCenter.x, y: stickyCenter.y)
ctx.rotate(by: -6 * .pi / 180)
let sticky = CGRect(x: -140, y: -140, width: 280, height: 280)
fillStroke(rounded(sticky.offsetBy(dx: 18, dy: -18), 40),
           fill: inkShadow, stroke: nil, width: 0)
fillStroke(rounded(sticky, 40), fill: pinkTint, stroke: ink, width: 16)
// Two "written" ink lines on the note.
for (i, w) in [150.0, 96.0].enumerated() {
    let line = CGRect(x: -75, y: CGFloat(-8 + 52 - i * 64), width: w, height: 24)
    fillStroke(rounded(line, 12), fill: ink, stroke: nil, width: 0)
}
ctx.restoreGState()

// 4. The magnet dot, centered on the door's top edge (the Tonight card's mark).
let magnetCenter = CGPoint(x: 512, y: CGFloat(size) - 260)    // visual (512, 260)
let magnetRect = CGRect(x: magnetCenter.x - 84, y: magnetCenter.y - 84,
                        width: 168, height: 168)
fillStroke(CGPath(ellipseIn: magnetRect, transform: nil),
           fill: pink, stroke: ink, width: 18)

// Write the PNG.
guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("no image/destination") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("wrote \(out)")
