import SwiftUI

// Reusable Sticker Aisle components. Reference renders: design_refs/2a-tokens.html
// and design_refs/home-fridge-door.html. Tilt only decorative elements (stickers,
// notes, magnets) — never buttons, nav, or text blocks. Max ONE sticker per screen.

// MARK: - Ink-bordered card

struct InkCardModifier: ViewModifier {
    var background: Color = Theme.paper
    var radius: CGFloat = Theme.Radius.card
    var borderColor: Color = Theme.ink
    var dashed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor,
                                  style: StrokeStyle(lineWidth: Theme.borderWidth,
                                                     dash: dashed ? [5, 4] : []))
            )
    }
}

extension View {
    func inkCard(background: Color = Theme.paper,
                 radius: CGFloat = Theme.Radius.card,
                 borderColor: Color = Theme.ink,
                 dashed: Bool = false) -> some View {
        modifier(InkCardModifier(background: background, radius: radius,
                                 borderColor: borderColor, dashed: dashed))
    }
}

// MARK: - Magnet dot (decorative circle pinned to card/note edges)

struct MagnetDot: View {
    var color: Color
    var size: CGFloat = 14

    // `size` is the fill diameter; the ink ring draws OUTSIDE it, matching the
    // mockup CSS (content-box width + border) — total diameter = size + 4.
    var body: some View {
        Circle()
            .fill(color)
            .padding(Theme.borderWidth)
            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
            .frame(width: size + 2 * Theme.borderWidth, height: size + 2 * Theme.borderWidth)
    }
}

// MARK: - Safety badge ("Caddie GF ✓" — a guarantee, not a preference)

struct SafetyBadge: View {
    var text: String
    var slot: PaletteSlot

    var body: some View {
        Text(text)
            .font(.nunito(11, .black))
            .foregroundStyle(slot.label)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(slot.tint, in: Capsule())
    }
}

// MARK: - Sticker chip (max one sticker moment per screen)

struct StickerChip: View {
    var text: String
    var rotation: Double = 2.5
    var shadowSlot: PaletteSlot = Palette.pink
    var background: Color = Palette.yellow.tint
    var foreground: Color = Theme.ink

    var body: some View {
        Text(text)
            .font(.nunito(10.5, .black))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .inkCard(background: background, radius: Theme.Radius.sticker)
            .hardShadow(shadowSlot.color, x: 2.5, y: 2.5)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Pill buttons

struct PillButtonStyle: ButtonStyle {
    var background: Color = Theme.paper
    var foreground: Color = Theme.ink
    var emphasis: Bool = false   // ink hard shadow + Baloo type
    var font: Font?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font ?? (emphasis ? .baloo(14.5, .heavy) : .nunito(12.5, .black)))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .inkCard(background: background, radius: Theme.Radius.pill)
            .hardShadow(emphasis ? Theme.ink : .clear,
                        x: emphasis ? 3 : 0, y: emphasis ? 3 : 0)
            .offset(x: configuration.isPressed && emphasis ? 2 : 0,
                    y: configuration.isPressed && emphasis ? 2 : 0)
            .opacity(configuration.isPressed && !emphasis ? 0.85 : 1)
    }
}

// MARK: - Sticky note

struct StickyNote<Content: View>: View {
    var slot: PaletteSlot
    var rotation: Double
    var magnetColor: Color
    var magnetAlignment: Alignment = .topLeading
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12))
            .inkCard(background: slot.tintAlt, radius: Theme.Radius.stickyNote)
            .softHardShadow(x: 3, y: 4)
            .overlay(alignment: magnetAlignment) {
                MagnetDot(color: magnetColor)
                    .offset(x: magnetAlignment == .topLeading ? 16 : -16, y: -8)
            }
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Blob avatar (pure code, never photoreal; kids pick shape + color)

struct BlobShape: Shape {
    var variant: Int

    func path(in rect: CGRect) -> Path {
        // Four-lobe blob: radii vary per corner by variant, like CSS
        // border-radius: 60% 40% 55% 45% / 50% 60% 40% 50%.
        let seeds: [[CGFloat]] = [
            [0.60, 0.40, 0.55, 0.45, 0.50, 0.60, 0.40, 0.50],
            [0.45, 0.58, 0.42, 0.55, 0.60, 0.42, 0.55, 0.45],
            [0.55, 0.45, 0.60, 0.40, 0.45, 0.55, 0.48, 0.58],
            [0.42, 0.60, 0.45, 0.55, 0.55, 0.45, 0.60, 0.42],
            [0.58, 0.44, 0.52, 0.50, 0.42, 0.58, 0.46, 0.54],
        ]
        let s = seeds[abs(variant) % seeds.count]
        let w = rect.width, h = rect.height
        let top = CGPoint(x: rect.minX + w * s[0], y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: rect.minY + h * s[4])
        let bottom = CGPoint(x: rect.minX + w * s[2], y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.minY + h * s[6])

        var p = Path()
        p.move(to: top)
        p.addQuadCurve(to: right, control: CGPoint(x: rect.maxX - w * 0.06, y: rect.minY + h * 0.08))
        p.addQuadCurve(to: bottom, control: CGPoint(x: rect.maxX - w * 0.04, y: rect.maxY - h * 0.06))
        p.addQuadCurve(to: left, control: CGPoint(x: rect.minX + w * 0.05, y: rect.maxY - h * 0.05))
        p.addQuadCurve(to: top, control: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.07))
        p.closeSubpath()
        return p
    }
}

struct BlobAvatar: View {
    var color: Color
    var variant: Int
    var size: CGFloat = 34

    var body: some View {
        BlobShape(variant: variant)
            .fill(color)
            .overlay(BlobShape(variant: variant).stroke(Theme.ink, lineWidth: Theme.borderWidth))
            .overlay(face)
            .frame(width: size, height: size)
    }

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.18) {
                Circle().fill(Theme.ink).frame(width: size * 0.09, height: size * 0.09)
                Circle().fill(Theme.ink).frame(width: size * 0.09, height: size * 0.09)
            }
            SmileShape()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: max(1.5, size * 0.05), lineCap: .round))
                .frame(width: size * 0.28, height: size * 0.12)
        }
        .offset(y: size * 0.02)
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.4))
        return p
    }
}

// MARK: - Effort dots (●○○ drawn as shapes)

/// Effort rendered as three drawn circles. The bundled Nunito files contain
/// neither U+25CF nor U+25CB, so text glyphs fall back to an oversized system
/// face — always use this view, never the characters.
struct EffortDots: View {
    var effort: Int                        // 1–3
    var color: Color = Theme.textSecondary
    var dotSize: CGFloat = 5.5

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                Group {
                    if i < effort {
                        Circle().fill(color)
                    } else {
                        Circle().strokeBorder(color, lineWidth: 1.2)
                    }
                }
                .frame(width: dotSize, height: dotSize)
            }
        }
        .accessibilityLabel("Effort \(effort) of 3")
    }
}

// MARK: - Section label (CAPS, tracked)

struct SectionLabel: View {
    var text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(.nunito(10.5, .black))
            .kerning(1.0)
            .foregroundStyle(color)
    }
}
