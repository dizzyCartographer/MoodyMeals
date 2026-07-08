import SwiftUI
import WidgetKit

// Cook-mode Live Activity — design_refs/2h-widgets.html, README §Screens.8.
// Message: dinner exists, it's handled. Dark room (#17131F), no ink outlines,
// yellow Baloo countdown, 4-segment step bar with palette fills.
//
// This file is compiled into BOTH targets: the widget extension (renders the
// activity) and the app (starts it via CookModeController) — ActivityKit
// matches the two sides through the shared `CookModeAttributes` type.

#if canImport(ActivityKit)
import ActivityKit

// MARK: - Attributes

struct CookModeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The moment dinner hits the table; rendered as a live countdown.
        var countdownTarget: Date
        /// 0 prep · 1 chop · 2 sizzle · 3 eat. Segments below the index are
        /// done (filled with palette slots); the rest wait, uncolored.
        var stepIndex: Int
    }

    var mealName: String   // "Taco night"
    var eatTime: String    // "6:00"
    var subLine: String    // "Chad on chop duty ✓ · tortillas warming"
}

// Demo content mirroring the mockup — shared by the app-side demo trigger
// (CookModeController) and the widget previews.
extension CookModeAttributes {
    static let demo = CookModeAttributes(
        mealName: "Taco night",
        eatTime: "6:00",
        subLine: "Chad on chop duty ✓ · tortillas warming")
}

extension CookModeAttributes.ContentState {
    /// Eats in 42 minutes, step 2 (sizzle) active: prep ✓ chop ✓.
    static var demo: CookModeAttributes.ContentState {
        CookModeAttributes.ContentState(
            countdownTarget: Date().addingTimeInterval(42 * 60),
            stepIndex: 2)
    }
}

// MARK: - Steps

enum CookModeSteps {
    static let names = ["prep", "chop", "sizzle", "eat"]
    static let fills: [Color] = [
        Palette.pink.color, Palette.yellow.color, Palette.green.color, Palette.blue.color,
    ]

    /// "prep ✓ · chop ✓ · sizzle · eat"
    static func caption(stepIndex: Int) -> String {
        names.enumerated()
            .map { i, name in i < stepIndex ? "\(name) ✓" : name }
            .joined(separator: " · ")
    }
}

// MARK: - Shared pieces

struct CookModeCountdown: View {
    var target: Date

    var body: some View {
        Text(timerInterval: Date.now...max(Date.now, target), countsDown: true, showsHours: false)
            .font(.baloo(17, .heavy))
            .foregroundStyle(Palette.yellow.color)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 56)
    }
}

struct CookModeStepBar: View {
    var stepIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i < stepIndex ? CookModeSteps.fills[i] : Color.white.opacity(0.18))
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct CookModeStepCaption: View {
    var stepIndex: Int

    var body: some View {
        Text(CookModeSteps.caption(stepIndex: stepIndex))
            .font(.nunito(10.5, .heavy))
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
    }
}

// MARK: - Lock screen / banner

struct CookModeLockScreenView: View {
    var attributes: CookModeAttributes
    var state: CookModeAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BlobAvatar(color: Palette.pink.color, variant: 1, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(attributes.mealName) · eats at \(attributes.eatTime)")
                        .font(.nunito(13.5, .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(attributes.subLine)
                        .font(.nunito(11, .heavy))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                Spacer(minLength: 8)
                CookModeCountdown(target: state.countdownTarget)
            }
            CookModeStepBar(stepIndex: state.stepIndex)
                .padding(.top, 11)
            CookModeStepCaption(stepIndex: state.stepIndex)
                .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16))
    }
}

// MARK: - Widget configuration

struct CookModeActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookModeAttributes.self) { context in
            CookModeLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Theme.liveActivityBackground)
                .activitySystemActionForegroundColor(Palette.yellow.color)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BlobAvatar(color: Palette.pink.color, variant: 1, size: 30)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.attributes.mealName) · eats at \(context.attributes.eatTime)")
                        .font(.nunito(13, .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookModeCountdown(target: context.state.countdownTarget)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        CookModeStepBar(stepIndex: context.state.stepIndex)
                        CookModeStepCaption(stepIndex: context.state.stepIndex)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Circle()
                    .fill(Palette.green.color)
                    .frame(width: 9, height: 9)
            } compactTrailing: {
                Text(context.attributes.eatTime)
                    .font(.nunito(11.5, .black))
                    .foregroundStyle(.white)
            } minimal: {
                Circle()
                    .fill(Palette.green.color)
                    .frame(width: 9, height: 9)
            }
            .keylineTint(Palette.green.color)
        }
    }
}

// MARK: - Preview

#Preview("cook mode", as: .content, using: CookModeAttributes.demo) {
    CookModeActivityWidget()
} contentStates: {
    CookModeAttributes.ContentState.demo
}

#endif
