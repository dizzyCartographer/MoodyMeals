import SwiftUI

// Celebration engine — README §Screens.9 / design_refs/2i-motion.html.
//
// Four styles, one rule set:
//   confetti pop  — everyday win
//   sticker slap  — milestone lands
//   marquee       — guarantee satisfied · quiet confidence, no fanfare
//   blob party    — THE RETURN only · the biggest visual moment in the app
//
// Laws enforced here (README §Design Laws 4 & 5):
//   · Colors always sample the user's palette slots (`Palette.slots`).
//   · Novelty is load-bearing: never the same style twice in a row —
//     the last style is persisted so the rule holds across launches.
//   · Misses/skips get ZERO motion. There is deliberately no WinKind for a
//     miss and no API to animate one. Calm is the response.
//
// The engine is standalone: it never touches AppState. Screens own a
// CelebrationCenter (or receive one) and mount `.celebrationHost(center:)`.

// MARK: - Wins (there is no case for a miss — that is the point)

/// The only things the app is allowed to animate. Every case is a win.
enum WinKind: Equatable {
    /// Everyday win — dinner logged, decide-for-me committed, small stuff.
    /// `message` is the little line that lands with the confetti ("nice.").
    case everyday(message: String)
    /// A milestone lands — `badge` is the sticker text ("DAY 5", "PB 24").
    case milestone(badge: String)
    /// The guarantee is satisfied ("covered thru Friday ✓"). Quiet.
    case guaranteeSatisfied
    /// THE RETURN — a comeback after a slump. Reserved for exactly that,
    /// because coming back is harder than never leaving.
    case theReturn

    /// The style this win asks for. Rotation (novelty law) may substitute —
    /// except THE RETURN, which is always the blob party.
    var preferredStyle: CelebrationStyle {
        switch self {
        case .everyday: return .confettiPop
        case .milestone: return .stickerSlap
        case .guaranteeSatisfied: return .marquee
        case .theReturn: return .blobParty
        }
    }

    /// The one line of copy a style renders for this win.
    var headline: String {
        switch self {
        case .everyday(let message): return message
        case .milestone(let badge): return badge
        case .guaranteeSatisfied: return "guarantee satisfied ✓"
        case .theReturn: return "THE RETURN"
        }
    }
}

// MARK: - Styles

enum CelebrationStyle: String, CaseIterable, Identifiable {
    case confettiPop
    case stickerSlap
    case marquee
    case blobParty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .confettiPop: return "confetti pop"
        case .stickerSlap: return "sticker slap"
        case .marquee: return "marquee"
        case .blobParty: return "blob party"
        }
    }

    /// Styles the rotation may substitute when a preferred style just ran.
    /// Blob party is never a substitute — it belongs to THE RETURN alone.
    static let rotatable: [CelebrationStyle] = [.confettiPop, .stickerSlap, .marquee]

    /// How long the overlay stays up before the host fades it away.
    var lifetime: TimeInterval {
        switch self {
        case .confettiPop: return 2.8   // pieces fall 1.4–2s, staggered ≤0.6s
        case .stickerSlap: return 1.8   // ~600ms slap + a beat to enjoy it
        case .marquee: return 3.0       // soft chase, then gone
        case .blobParty: return 4.2     // full takeover — earns the screen time
        }
    }
}

// MARK: - Active celebration

struct ActiveCelebration: Identifiable, Equatable {
    let id: UUID
    let style: CelebrationStyle
    let win: WinKind

    var headline: String { win.headline }
}

// MARK: - Center

/// Owns which celebration is on screen, picks styles under the novelty law,
/// and auto-dismisses. Standalone — never reads or writes AppState.
@MainActor
final class CelebrationCenter: ObservableObject {

    /// What the `.celebrationHost` overlay is currently showing (if anything).
    @Published private(set) var active: ActiveCelebration?

    /// Last style shown — persisted so "never twice in a row" survives
    /// app launches (novelty is load-bearing, README law 5).
    @AppStorage("moody.celebrations.lastStyle") private var lastStyleRaw: String = ""

    private var dismissTask: Task<Void, Never>?

    var lastStyle: CelebrationStyle? { CelebrationStyle(rawValue: lastStyleRaw) }

    /// The whole public surface: hand it a win, it does the rest —
    /// picks a style (never the last one again), shows it, dismisses it.
    func celebrate(_ win: WinKind) {
        let style = style(for: win)
        lastStyleRaw = style.rawValue

        let celebration = ActiveCelebration(id: UUID(), style: style, win: win)
        active = celebration

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(style.lifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss(ifCurrent: celebration.id)
        }
    }

    /// Skip straight to done (blob party is tappable-to-skip; screens may
    /// also call this when navigating away).
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        active = nil
    }

    private func dismiss(ifCurrent id: UUID) {
        guard active?.id == id else { return }
        active = nil
    }

    // MARK: Style rotation (novelty law)

    private func style(for win: WinKind) -> CelebrationStyle {
        // THE RETURN always gets the blob party — it is the one moment big
        // enough that the rotation yields to it (and it can't realistically
        // repeat back-to-back: you can only come back after being away).
        if case .theReturn = win { return .blobParty }

        let preferred = win.preferredStyle
        guard preferred.rawValue == lastStyleRaw else { return preferred }

        // Same style twice in a row is forbidden: step around the ring of
        // everyday-eligible styles instead. Blob party is never in the ring.
        let ring = CelebrationStyle.rotatable
        let index = ring.firstIndex(of: preferred) ?? 0
        return ring[(index + 1) % ring.count]
    }
}

// MARK: - The miss tripwire

extension CelebrationCenter {
    /// Misses and skips get ZERO motion (README law 4): no animation, no
    /// styling, no "gentler" celebration. Calm is the response. This symbol
    /// exists only so the compiler stops anyone who reaches for it.
    @available(*, unavailable, message: "Misses get zero motion. Calm is the response — there is no celebration API for a miss, on purpose.")
    func celebrateMiss() {}
}

// MARK: - Preview

#Preview("Celebration engine") {
    CelebrationDemoView()
        .environmentObject(AppState())
}
