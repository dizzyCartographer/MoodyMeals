import SwiftUI

// Celebration overlays — pixel-faithful to design_refs/2i-motion.html:
//   mfall   translateY(-24 → beyond bottom) rotate(0→200°), linear, 1.4–2s
//   mstamp  scale 0→1.18→0.95→1 · rotate −14°→+4°→−3° · ~600ms spring-like
//   mchase  stationary bulbs pulsing opacity .12→1→.12 in sequence (the
//           light chases around the edges, the dots never move)
//   mbounce translateY 0→−16→0, ease-in-out, staggered 150ms
//
// Reduce Motion: every style falls back to a static composition that only
// fades in/out (the host's ≤250ms ease-out opacity transition).
// Colors always sample `Palette.slots` — never fixed product colors.

// MARK: - Host modifier

extension View {
    /// Mount on any screen. Overlays the active celebration and auto-dismisses
    /// (the center owns the clock). Confetti/sticker/marquee never block
    /// touches; the blob party is a deliberate takeover (tap to skip).
    func celebrationHost(center: CelebrationCenter) -> some View {
        modifier(CelebrationHostModifier(center: center))
    }
}

struct CelebrationHostModifier: ViewModifier {
    @ObservedObject var center: CelebrationCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if let celebration = center.active {
                    CelebrationOverlay(celebration: celebration,
                                       reduceMotion: reduceMotion,
                                       onSkip: { center.dismiss() })
                        .id(celebration.id)
                        .transition(.opacity)
                }
            }
            // Standard transition budget: ≤250ms ease-out.
            .animation(.easeOut(duration: 0.25), value: center.active)
    }
}

// MARK: - Overlay (switches styles)

struct CelebrationOverlay: View {
    let celebration: ActiveCelebration
    let reduceMotion: Bool
    var onSkip: () -> Void = {}

    var body: some View {
        switch celebration.style {
        case .confettiPop:
            CelebrationConfettiPopView(message: celebration.headline,
                                       reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        case .stickerSlap:
            CelebrationStickerSlapView(badge: celebration.headline,
                                       reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        case .marquee:
            CelebrationMarqueeView(caption: celebration.headline,
                                   reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        case .blobParty:
            CelebrationBlobPartyView(reduceMotion: reduceMotion, onSkip: onSkip)
        }
    }
}

// MARK: - Style 1 · Confetti pop (everyday win)

struct CelebrationConfettiPiece: Identifiable {
    let id = UUID()
    let unitX: CGFloat       // 0–1 across the width
    let restUnitY: CGFloat   // static scatter position for Reduce Motion
    let size: CGFloat        // 8–11, like the mockup pieces
    let isSquare: Bool       // squares (r≈3) and dots alternate
    let color: Color
    let duration: Double     // mfall: 1.4–2.0s
    let delay: Double        // staggered starts, ≤0.6s
    let spin: Double         // mfall rotates ~200°

    static func burst(count: Int) -> [CelebrationConfettiPiece] {
        (0..<count).map { i in
            CelebrationConfettiPiece(
                unitX: .random(in: 0.04...0.96),
                restUnitY: .random(in: 0.08...0.85),
                size: .random(in: 8...11),
                isSquare: i.isMultiple(of: 2),
                color: Palette.slots[i % Palette.slots.count].color,
                duration: .random(in: 1.4...2.0),
                delay: .random(in: 0...0.6),
                spin: .random(in: 160...240) * (i.isMultiple(of: 3) ? -1 : 1))
        }
    }
}

/// The raw falling-pieces field. Shared by confetti pop and the blob party
/// (THE RETURN stacks styles). With Reduce Motion the pieces sit still,
/// scattered, and simply fade with the host.
struct CelebrationConfettiField: View {
    var pieceCount: Int = 26
    let reduceMotion: Bool

    @State private var fall = false
    @State private var pieces: [CelebrationConfettiPiece]

    init(pieceCount: Int = 26, reduceMotion: Bool) {
        self.pieceCount = pieceCount
        self.reduceMotion = reduceMotion
        _pieces = State(initialValue: CelebrationConfettiPiece.burst(count: pieceCount))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    pieceShape(piece)
                        .frame(width: piece.size, height: piece.size)
                        .rotationEffect(.degrees(fall && !reduceMotion ? piece.spin : 0))
                        .position(x: piece.unitX * geo.size.width,
                                  y: yPosition(for: piece, in: geo.size))
                        .animation(reduceMotion ? nil :
                                    .linear(duration: piece.duration).delay(piece.delay),
                                   value: fall)
                }
            }
        }
        .onAppear { fall = true }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func pieceShape(_ piece: CelebrationConfettiPiece) -> some View {
        if piece.isSquare {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(piece.color)
        } else {
            Circle().fill(piece.color)
        }
    }

    private func yPosition(for piece: CelebrationConfettiPiece, in size: CGSize) -> CGFloat {
        if reduceMotion { return piece.restUnitY * size.height }
        return fall ? size.height + 24 : -24
    }
}

struct CelebrationConfettiPopView: View {
    let message: String
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            CelebrationConfettiField(reduceMotion: reduceMotion)
                .ignoresSafeArea()
            if !message.isEmpty {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.baloo(15, .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .inkCard(background: Theme.paper, radius: Theme.Radius.pill)
                        .softHardShadow(x: 3, y: 3)
                        .padding(.bottom, 215)   // clears the home tank check + footer
                }
            }
        }
    }
}

// MARK: - Style 2 · Sticker slap (milestone lands)

struct CelebrationStickerSlapView: View {
    let badge: String
    let reduceMotion: Bool

    @State private var slapped = false

    private struct SlapValue {
        var scale: CGFloat = 0
        var rotationDegrees: Double = -14
        var opacity: Double = 0
    }

    var body: some View {
        ZStack {
            if reduceMotion {
                // Static: final resting pose, gentle host fade only.
                badgeView.rotationEffect(.degrees(-3))
            } else {
                badgeView
                    // mstamp: scale 0→1.18→0.95→1 · rotate −14°→+4°→−3° · ~600ms
                    .keyframeAnimator(initialValue: SlapValue(), trigger: slapped) { view, value in
                        view
                            .scaleEffect(value.scale)
                            .rotationEffect(.degrees(value.rotationDegrees))
                            .opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(1.18, duration: 0.30)
                            CubicKeyframe(0.95, duration: 0.16)
                            CubicKeyframe(1.0, duration: 0.14)
                        }
                        KeyframeTrack(\.rotationDegrees) {
                            CubicKeyframe(4, duration: 0.30)
                            CubicKeyframe(-3, duration: 0.18)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.16)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { slapped = true }
    }

    // The badge is a decorative sticker — tilt allowed (it lands at −3°).
    private var badgeView: some View {
        Text(badge)
            .font(.baloo(16, .heavy))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .inkCard(background: Palette.yellow.color, radius: 12)
            .hardShadow(Palette.pink.color, x: 3, y: 3)
    }
}

// MARK: - Style 3 · Marquee (guarantee satisfied — quiet confidence)

struct CelebrationMarqueeView: View {
    let caption: String
    let reduceMotion: Bool

    @State private var start = Date()

    private let bulbCount = 14
    private let bulbSize: CGFloat = 9
    private let edgeInset: CGFloat = 10
    private let cycle: TimeInterval = 1.6   // one lap of light around the edges

    var body: some View {
        ZStack {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSince(start)
                    ZStack {
                        ForEach(0..<bulbCount, id: \.self) { index in
                            let fraction = Double(index) / Double(bulbCount)
                            Circle()
                                .fill(Palette.slots[index % Palette.slots.count].color)
                                .frame(width: bulbSize, height: bulbSize)
                                .opacity(reduceMotion ? 0.6 : chaseOpacity(t: t, phase: fraction))
                                .position(perimeterPoint(fraction: fraction, in: geo.size))
                        }
                    }
                }
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                Text(caption)
                    .font(.baloo(15, .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .inkCard(background: Theme.paper, radius: Theme.Radius.pill)
                    .softHardShadow(x: 3, y: 3)
                    .padding(.bottom, 215)   // clears the home tank check + footer
            }
        }
    }

    /// mchase: bulbs never move — the light does. Opacity .12→1→.12,
    /// phased so the glow walks the perimeter.
    private func chaseOpacity(t: TimeInterval, phase: Double) -> Double {
        let p = (t / cycle - phase).truncatingRemainder(dividingBy: 1)
        let local = p < 0 ? p + 1 : p
        let dim = 0.12
        if local < 0.25 { return dim + (1 - dim) * (local / 0.25) }
        if local < 0.55 { return 1 - (1 - dim) * ((local - 0.25) / 0.30) }
        return dim
    }

    /// Evenly spaced points marching clockwise around the screen edge,
    /// starting at the top-left corner (like the mockup's corner dots).
    private func perimeterPoint(fraction: Double, in size: CGSize) -> CGPoint {
        let w = max(size.width - edgeInset * 2, 1)
        let h = max(size.height - edgeInset * 2, 1)
        let perimeter = 2 * (w + h)
        var d = fraction * perimeter

        if d < w { return CGPoint(x: edgeInset + d, y: edgeInset) }
        d -= w
        if d < h { return CGPoint(x: edgeInset + w, y: edgeInset + d) }
        d -= h
        if d < w { return CGPoint(x: edgeInset + w - d, y: edgeInset + h) }
        d -= w
        return CGPoint(x: edgeInset, y: edgeInset + h - d)
    }
}

// MARK: - Style 4 · Blob party (THE RETURN only — full takeover)

struct CelebrationBlobPartyView: View {
    let reduceMotion: Bool
    var onSkip: () -> Void = {}

    @State private var bouncing = false

    // The cast, palette slots only (mirrors the demo household's blob colors
    // without touching AppState — the engine stays standalone).
    private let cast: [(color: Color, variant: Int)] = [
        (Palette.pink.color, 0),
        (Palette.purple.color, 1),
        (Palette.green.color, 2),
        (Palette.blue.color, 3),
        (Palette.yellow.color, 4),
    ]

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            // THE RETURN stacks styles: confetti joins the takeover.
            CelebrationConfettiField(pieceCount: 32, reduceMotion: reduceMotion)
                .ignoresSafeArea()

            VStack(spacing: Theme.Space.l) {
                HStack(alignment: .bottom, spacing: Theme.Space.m) {
                    ForEach(Array(cast.enumerated()), id: \.offset) { index, member in
                        BlobAvatar(color: member.color, variant: member.variant, size: 52)
                            // mbounce: translateY 0→−16→0, staggered 150ms.
                            .offset(y: bouncing && !reduceMotion ? -16 : 0)
                            .animation(reduceMotion ? nil :
                                        .easeInOut(duration: 0.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.15),
                                       value: bouncing)
                    }
                }

                Text("THE RETURN")
                    .font(.baloo(30, .heavy))
                    .foregroundStyle(Palette.yellow.color)

                Text("the parade, as promised. welcome back.")
                    .font(.nunito(12.5, .heavy))
                    .foregroundStyle(Theme.paper.opacity(0.75))
            }

            VStack {
                Spacer()
                Text("tap anywhere to get back to dinner")
                    .font(.nunito(11, .heavy))
                    .foregroundStyle(Theme.paper.opacity(0.45))
                    .padding(.bottom, 28)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSkip() }
        // The takeover is skippable by tap; VoiceOver gets the same exit —
        // the whole screen reads as one button whose activation dismisses.
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("The return — welcome back. Double-tap to dismiss")
        .accessibilityAction { onSkip() }
        .onAppear {
            if !reduceMotion { bouncing = true }
        }
    }
}

// MARK: - Demo harness (previews / integration reference)

/// Not a shipping screen — shows every win wired the way real screens will
/// wire them. Note what is absent: there is no miss button, because there is
/// no miss API.
struct CelebrationDemoView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var center = CelebrationCenter()

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Text("Celebrations")
                .font(.baloo(26, .heavy))
                .foregroundStyle(Theme.ink)

            SectionLabel(text: "one tap per win kind")

            Button("everyday win · \u{201C}nice.\u{201D}") {
                center.celebrate(.everyday(message: "nice."))
            }
            .buttonStyle(PillButtonStyle())

            Button("milestone · \(appState.streak.displayDay.uppercased())") {
                center.celebrate(.milestone(badge: appState.streak.displayDay.uppercased()))
            }
            .buttonStyle(PillButtonStyle(background: Palette.yellow.color, emphasis: true))

            Button("guarantee satisfied ✓") {
                center.celebrate(.guaranteeSatisfied)
            }
            .buttonStyle(PillButtonStyle())

            Button("THE RETURN") {
                center.celebrate(.theReturn)
            }
            .buttonStyle(PillButtonStyle(background: Theme.ink,
                                         foreground: Theme.paper, emphasis: true))

            if let last = center.lastStyle {
                SectionLabel(text: "last style · \(last.displayName)")
                    .padding(.top, Theme.Space.s)
            }
            // D-48: the win-only list IS the statement — narrating that misses
            // aren't tracked converts calm into commentary. (Line removed.)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.shelf)
        .celebrationHost(center: center)
    }
}

// MARK: - Previews

#Preview("Celebration overlays") {
    CelebrationDemoView()
        .environmentObject(AppState())
}
