import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// App-side trigger for the cook-mode Live Activity (demo affordance).
///
/// The integrator wires the call — e.g. from `MoodyApp`/`RootView` `.task`
/// or `onAppear`:
///
///     CookModeController.startIfDemoRequested()
///
/// Launch the app with the environment variable `MOODY_DEMO=cookmode`
/// (Xcode scheme ▸ Run ▸ Arguments ▸ Environment Variables, or
/// `simctl launch --terminate-running-process <udid> com.mariayarley.Moody
/// --env MOODY_DEMO=cookmode` style) to start the activity with the demo
/// content: Taco night, eats at 6:00, step 2 (sizzle) active.
enum CookModeController {

    static func startIfDemoRequested() {
        guard ProcessInfo.processInfo.environment["MOODY_DEMO"] == "cookmode" else { return }
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // One cook mode at a time: relaunching with the demo flag while an
        // activity is already live would stack a duplicate — skip instead.
        guard Activity<CookModeAttributes>.activities.isEmpty else { return }
        do {
            _ = try Activity.request(
                attributes: CookModeAttributes.demo,
                content: ActivityContent(state: .demo, staleDate: nil))
        } catch {
            // Demo-only affordance: if the system refuses (activity budget,
            // Settings toggle), stay quiet — calm is the response (law 4).
        }
        #endif
    }
}
