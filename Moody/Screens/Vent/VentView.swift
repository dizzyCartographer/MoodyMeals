import SwiftUI

// The Vent — the quiet room (design_refs/2e-vent.html, README §Screens.5).
// The ONE screen where the sticker language deliberately goes off: dark dim
// room, NO ink outlines, NO stickers, NO tilt, single purple accent
// (Palette.purple). Soft glows are allowed here — this screen is exempt from
// the zero-blur hard-shadow language. Recording is fake in v1: the mic
// toggles on tap and the waveform animates (unless Reduce Motion is on).

struct VentView: View {
    @EnvironmentObject var appState: AppState

    /// Wired by the parent later; called when the vent session ends.
    var onClose: (() -> Void)? = nil

    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 0) {
            Text("THE VENT")
                .font(.nunito(12, .heavy))
                .kerning(2.16) // .18em of 12pt
                .foregroundStyle(VentColor.muted)
                .padding(.top, 10)

            VStack(spacing: 26) {
                Text("say it ugly.\nnobody's grading.")
                    .font(Font.quicksand(22))
                    .foregroundStyle(VentColor.bright)
                    .multilineTextAlignment(.center)

                VentMicButton(isRecording: $isRecording)

                VentWaveform(isRecording: isRecording)

                receptionCard

                VStack(spacing: 8) {
                    Button("make tonight zero-effort") {
                        appState.setTank(.fumes)
                        onClose?()
                    }
                    .buttonStyle(VentPillStyle(
                        background: Palette.purple.color.opacity(0.12),
                        border: Palette.purple.color.opacity(0.5),
                        foreground: VentColor.lilac))

                    Button("that's all. just needed out.") {
                        onClose?()
                    }
                    .buttonStyle(VentPillStyle(
                        background: .clear,
                        border: Color.white.opacity(0.14),
                        foreground: VentColor.muted))
                }
                .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("vents self-shred in 24h unless you keep them · nothing here touches your plan unless you say so")
                .font(.nunito(11, .bold))
                .foregroundStyle(VentColor.footer)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ventBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // radial-gradient(120% 90% at 50% 0%, #2C2540 0%, #1E1930 55%, #181425 100%)
    private var ventBackground: some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Theme.ventTop, location: 0),
                .init(color: VentColor.mid, location: 0.55),
                .init(color: Theme.ventBottom, location: 1),
            ]),
            center: UnitPoint(x: 0.5, y: 0),
            startRadius: 0,
            endRadius: 820
        )
    }

    private var receptionCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECEPTION")
                .font(.nunito(11, .black))
                .kerning(0.88) // .08em of 11pt
                .foregroundStyle(VentColor.muted)
            Text("heard. that was a lot of day for one person.")
                .font(.nunito(14, .bold))
                .foregroundStyle(VentColor.bright)
                .lineLimit(1)
                .minimumScaleFactor(0.95)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(width: 300)
    }
}

// MARK: - Colors local to the quiet room (no ink, no paper here)

private enum VentColor {
    static let mid = Color(hex: 0x1E1930)     // gradient mid-stop + mic glyph
    static let bright = Color(hex: 0xEDE8F7)  // headline + reception body
    static let muted = Color(hex: 0x8E82A3)   // labels + quiet pill text
    static let footer = Color(hex: 0x5F5578)
    static let lilac = Color(hex: 0xD9CFF2)   // primary pill text
}

// MARK: - Mic button (112pt, soft purple halo — glow allowed on this screen)

private struct VentMicButton: View {
    @Binding var isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if reduceMotion {
                isRecording.toggle()
            } else {
                withAnimation(.easeOut(duration: 0.25)) { isRecording.toggle() }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Palette.purple.color.opacity(0.16))
                    .frame(width: 112, height: 112)
                    .shadow(color: Palette.purple.color.opacity(isRecording ? 0.45 : 0.28),
                            radius: 30)
                Circle()
                    .fill(Palette.purple.color)
                    .frame(width: 84, height: 84)
                micGlyph
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "stop venting" : "start venting")
        .accessibilityHint("nothing here touches your plan unless you say so")
    }

    // Ring stays centered on the purple circle; the stem hangs below it via an
    // overlay so it doesn't shift the ring off-center (mockup: bottom:-10px).
    private var micGlyph: some View {
        Capsule()
            .strokeBorder(VentColor.mid, lineWidth: 3)
            .frame(width: 18, height: 26)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(VentColor.mid)
                    .frame(width: 3, height: 7)
                    .offset(y: 10)
            }
    }
}

// MARK: - Live waveform (fake; bars oscillate while "recording")

private struct VentWaveform: View {
    var isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private static let restHeights: [CGFloat] = [10, 18, 26, 14, 22, 8]
    private static let peakHeights: [CGFloat] = [22, 8, 12, 26, 10, 20]
    private static let restOpacities: [Double] = [0.4, 0.6, 1, 0.7, 0.85, 0.4]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { i in
                Capsule()
                    .fill(Palette.purple.color)
                    .opacity(opacity(i))
                    .frame(width: 4, height: height(i))
                    .animation(barAnimation(i), value: pulse)
                    .animation(.easeOut(duration: 0.2), value: isRecording)
            }
        }
        .frame(height: 26)
        .onChange(of: isRecording) { _, recording in
            pulse = recording && !reduceMotion
        }
        .accessibilityHidden(true)
    }

    private func height(_ i: Int) -> CGFloat {
        guard isRecording, !reduceMotion else { return Self.restHeights[i] }
        return pulse ? Self.peakHeights[i] : Self.restHeights[i]
    }

    /// Reduce Motion fallback: no height animation — recording state reads
    /// as a single gentle opacity change instead (README §Motion).
    private func opacity(_ i: Int) -> Double {
        isRecording ? 1 : Self.restOpacities[i]
    }

    private func barAnimation(_ i: Int) -> Animation {
        guard isRecording, !reduceMotion else { return .easeOut(duration: 0.2) }
        return .easeInOut(duration: 0.42)
            .repeatForever(autoreverses: true)
            .delay(Double(i) * 0.06)
    }
}

// MARK: - Quiet pill (translucent borders — deliberately NOT PillButtonStyle,
// which carries ink borders and paper that don't exist in this room)

private struct VentPillStyle: ButtonStyle {
    var background: Color
    var border: Color
    var foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nunito(14, .heavy))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    VentView()
        .environmentObject(AppState())
}
