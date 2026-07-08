import SwiftUI

// Design tokens — source of truth: design_handoff_moody_app/README.md §Design Tokens.
// Fixed core colors are constants; the 5 accent slots are Ria's demo palette and
// must stay swappable (law 6: slots come from the user's favorite colors).

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    // MARK: Fixed core
    static let ink = Color(hex: 0x2A2440)
    static let paper = Color.white
    static let shelf = Color(hex: 0xF7F4EE)      // standard screen background
    static let fridge = Color(hex: 0xEFEBE2)     // home screen background
    static let textSecondary = Color(hex: 0x8A84A0)
    static let textDisabled = Color(hex: 0xB3AECB) // also dashed empty-slot borders
    static let stickyShadow = Color(hex: 0x2A2440).opacity(0.13)

    // Vent room is the one place the sticker language goes quiet (README §5)
    static let ventTop = Color(hex: 0x2C2540)
    static let ventBottom = Color(hex: 0x181425)
    static let liveActivityBackground = Color(hex: 0x17131F)

    // MARK: Spacing / radii
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 20
    }

    enum Radius {
        static let card: CGFloat = 20
        static let cardLarge: CGFloat = 22
        static let pill: CGFloat = 999
        static let sticker: CGFloat = 10   // also week magnets
        static let stickyNote: CGFloat = 6
        static let tankSegment: CGFloat = 16
        static let widget: CGFloat = 34
    }

    static let borderWidth: CGFloat = 2
}

// MARK: - User palette slots (Ria's demo values — NOT constants of the product)

struct PaletteSlot: Identifiable, Equatable {
    let id: String
    let color: Color      // full-strength accent
    let tint: Color       // ≈82% toward paper; badge/note backgrounds
    let tintAlt: Color    // secondary tint seen in mockups (falls back to tint)
    let label: Color      // dark text that sits on the tint
    let labelMuted: Color // quieter companion label on the tint

    init(id: String, color: UInt32, tint: UInt32, tintAlt: UInt32? = nil,
         label: UInt32, labelMuted: UInt32? = nil) {
        self.id = id
        self.color = Color(hex: color)
        self.tint = Color(hex: tint)
        self.tintAlt = Color(hex: tintAlt ?? tint)
        self.label = Color(hex: label)
        self.labelMuted = Color(hex: labelMuted ?? label)
    }
}

enum Palette {
    static let pink = PaletteSlot(id: "her-1", color: 0xFF7BAC, tint: 0xFDE7F0, tintAlt: 0xFFE3EE,
                                  label: 0xD46A92, labelMuted: 0xB04A72)
    static let green = PaletteSlot(id: "her-2", color: 0x8CC63E, tint: 0xE9F5D3,
                                   label: 0x5F7F28, labelMuted: 0x6B8A2E)
    // labelMuted deliberately darkened from the mockup's #B3A075 (2.4:1 on the
    // tint) to the primary label — readability adjudication, 2026-07-08.
    static let yellow = PaletteSlot(id: "her-3", color: 0xFFD34E, tint: 0xFFF4CE, tintAlt: 0xFFF6D8,
                                    label: 0x8A6D1E)
    static let blue = PaletteSlot(id: "her-4", color: 0x5BC2E7, tint: 0xE1F1FA,
                                  label: 0x3E7A96)
    static let purple = PaletteSlot(id: "her-5", color: 0x9B7EDE, tint: 0xEFE8FA,
                                    label: 0x8E77B8)
    static let slots: [PaletteSlot] = [pink, green, yellow, blue, purple]
}

// MARK: - Type

// fixedSize on purpose: the design's pt sizes are load-bearing and several
// screens are fixed-height, non-scrolling layouts that would break under
// Dynamic Type scaling. Dynamic Type support is deliberate future work —
// see HANDOFF.md.
extension Font {
    /// Baloo 2 — display / card titles. Weights: 600, 700, 800.
    static func baloo(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        let name: String
        switch weight {
        case .semibold: name = "Baloo2-SemiBold"
        case .bold: name = "Baloo2-Bold"
        default: name = "Baloo2-ExtraBold"
        }
        return .custom(name, fixedSize: size)
    }

    /// Quicksand — used ONLY on the Vent screen (its mockup's dedicated face).
    static func quicksand(_ size: CGFloat) -> Font {
        .custom("Quicksand-SemiBold", fixedSize: size)
    }

    /// Nunito — body / UI. Weights: 700, 800, 900.
    static func nunito(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .black: name = "Nunito-Black"
        case .heavy: name = "Nunito-ExtraBold"
        default: name = "Nunito-Bold"
        }
        return .custom(name, fixedSize: size)
    }
}

// MARK: - Hard offset shadows (zero blur — the whole look depends on this)

extension View {
    /// Emphasis shadow: `3px 3px 0 ink` on buttons, `4-5px 5px 0 <slot>` on feature cards.
    /// compositingGroup flattens the subtree first so the shadow comes off the
    /// combined silhouette (CSS box-shadow semantics) — without it, SwiftUI
    /// shadows every sublayer (fill, strokeBorder overlay) separately and the
    /// border's shadow bleeds inside the shape.
    func hardShadow(_ color: Color = Theme.ink, x: CGFloat = 3, y: CGFloat = 3) -> some View {
        compositingGroup().shadow(color: color, radius: 0, x: x, y: y)
    }

    /// Passive depth: `3-5px 4-5px 0 rgba(ink, .12-.14)`.
    func softHardShadow(x: CGFloat = 4, y: CGFloat = 4) -> some View {
        compositingGroup().shadow(color: Theme.stickyShadow, radius: 0, x: x, y: y)
    }
}
