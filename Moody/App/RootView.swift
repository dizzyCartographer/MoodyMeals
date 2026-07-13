import SwiftUI

// Navigation hub. Layout law: navigation never moves, actions never rename.
// Home is the permanent root; everything else pushes or covers and returns.

enum Route: Hashable {
    case week, shopping, streaks, thread
    case meals            // B-1 library
    case meal(UUID)       // B-1 detail — the "tap a meal" destination
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var celebrations = CelebrationCenter()
    @State private var path: [Route] = []
    @State private var showVent = false
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        NavigationStack(path: $path) {
            FridgeHomeView(
                onOpenThread: { path.append(.thread) },
                onOpenStreaks: { path.append(.streaks) },
                onOpenWeek: { path.append(.week) },
                onOpenShopping: { path.append(.shopping) },
                onOpenMeals: { path.append(.meals) },
                onOpenVent: { showVent = true },
                onWin: { celebrations.celebrate(.everyday(message: "decided. done.")) }
            )
            .navigationDestination(for: Route.self) { route in
                Group {
                    switch route {
                    case .week:
                        WeekPlanView(onOpenShopping: { path.append(.shopping) })
                    case .shopping:
                        ShoppingView()
                    case .streaks:
                        StreaksView()
                    case .thread:
                        ThreadView()
                    case .meals:
                        MealLibraryView(onOpenMeal: { path.append(.meal($0)) })
                    case .meal(let id):
                        MealDetailView(id: id)
                    }
                }
                // The mockups have no top bar, and system/toolbar chrome is
                // glassy — off-language on a kit built entirely from ink
                // borders and zero-blur shadows. Hide the bar and float a
                // kit-styled back chip instead.
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaPadding(.top, 48)   // pushed screens' titles clear the back chip
                .overlay(alignment: .topLeading) {
                    Button { if !path.isEmpty { path.removeLast() } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .background(Theme.paper, in: Circle())
                            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                            .hardShadow(Theme.ink, x: 2, y: 2)
                            .frame(minWidth: 48, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Back")
                    .padding(.leading, 10)
                }
            }
        }
        .tint(Theme.ink)
        .celebrationHost(center: celebrations)
        .fullScreenCover(isPresented: $showVent) {
            VentView(onClose: { showVent = false })
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded },
                                              set: { hasOnboarded = !$0 })) {
            OnboardingView(onDone: { hasOnboarded = true })
        }
        // .task, not .onAppear: onAppear re-fires every time a fullScreenCover
        // dismisses, which would re-apply the debug route (onboarding could
        // never be exited) and stack duplicate Live Activities.
        .task {
            applyDebugRoute()
            CookModeController.startIfDemoRequested()
        }
        .onOpenURL(perform: handleWidgetURL)
    }

    /// Widget taps: moody://decide, moody://tonight, moody://tank/fumes, moody://tank/steady.
    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "moody" else { return }
        path = []
        switch (url.host, url.pathComponents.dropFirst().first) {
        case ("decide", _):
            appState.decideForMe()
            celebrations.celebrate(.everyday(message: "decided. done."))
        case ("tank", let level?):
            if let tank = Tank.allCases.first(where: { $0.rawValue.lowercased() == level }) {
                appState.setTank(tank)
            }
        default:
            break   // moody://tonight just opens home
        }
    }

    /// Screenshot/verification hook: launch with SIMCTL_CHILD_MOODY_SCREEN=<name>
    /// to land directly on a screen. Debug convenience only — no user-facing role.
    private func applyDebugRoute() {
        // MOODY_DEMO=decide performs a real decide-for-me on launch (commit +
        // celebration) so both the confetti overlay and persistence can be
        // exercised headlessly. Independent of MOODY_SCREEN — works standalone.
        // MOODY_DEMO=addmeal exercises the real create path headlessly
        // (B-1 verification: create → relaunch → still in the library).
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "addmeal" {
            appState.createMeal(from: MealDraft(
                title: "Debug added meal", notes: "created by MOODY_DEMO=addmeal"))
        }
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "decide" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                appState.decideForMe()
                celebrations.celebrate(.everyday(message: "decided. done."))
            }
        }
        guard let screen = ProcessInfo.processInfo.environment["MOODY_SCREEN"] else { return }
        if screen != "onboarding" { hasOnboarded = true }
        switch screen {
        case "week": path = [.week]
        case "shopping": path = [.shopping]
        case "streaks": path = [.streaks]
        case "thread": path = [.thread]
        case "meals": path = [.meals]
        case "vent": showVent = true
        case "onboarding": hasOnboarded = false
        default: break
        }
    }
}
