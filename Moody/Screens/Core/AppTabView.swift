import SwiftUI

// D-56: the basics-first native shell. Standard tab bar — navigation is
// never a puzzle. Her palette survives as the accent; the sticker-aisle
// look is preserved at tag `sticker-aisle-v1` (Attic/ holds the screens).

struct AppTabView: View {
    @EnvironmentObject var appState: AppState

    enum Tab: String { case today, plan, meals, shopping, settings }
    @State private var tab: Tab = .today
    @State private var mealsPath = NavigationPath()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "fork.knife") }
                .tag(Tab.today)
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(Tab.plan)
            NavigationStack(path: $mealsPath) {
                MealLibraryView()
                    .navigationDestination(for: UUID.self) { MealDetailView(id: $0) }
                    .navigationDestination(for: RecipeRoute.self) { RecipeDetailView(recipeID: $0.id) }
            }
            .tabItem { Label("Meals", systemImage: "book") }
            .tag(Tab.meals)
            NavigationStack { ShoppingView() }
                .tabItem { Label("Shopping", systemImage: "cart") }
                .tag(Tab.shopping)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Palette.pink.color)
        .task { applyDebugRoute(); CookModeController.startIfDemoRequested() }
        .onOpenURL(perform: handleWidgetURL)
    }

    /// Widget taps: moody://decide, moody://tonight, moody://tank/<level>.
    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "moody" else { return }
        tab = .today
        switch (url.host, url.pathComponents.dropFirst().first) {
        case ("decide", _):
            appState.decideForMe()
        case ("tank", let level?):
            if let tank = Tank.allCases.first(where: { $0.rawValue.lowercased() == level }) {
                appState.setTank(tank)
            }
        default:
            break
        }
    }

    /// SIMCTL_CHILD_MOODY_SCREEN=<today|plan|meals|shopping|settings|mealdetail|run>
    /// Navigation only. The WRITE-flavored demo hooks (decide/addmeal/addrecipe/
    /// completerun/assignfuture) are gone: they verified their features, then
    /// one demonstrably double-fired across launches and seeded phantom data.
    /// Verification writes go through targeted debug builds from now on.
    private func applyDebugRoute() {
        guard let screen = ProcessInfo.processInfo.environment["MOODY_SCREEN"] else { return }
        switch screen {
        case "today": tab = .today
        case "plan": tab = .plan
        case "meals": tab = .meals
        case "shopping": tab = .shopping
        case "settings": tab = .settings
        case "mealdetail":
            tab = .meals
            if let meal = appState.library.max(by: {
                $0.recipes.count + $0.directItems.count
                    < $1.recipes.count + $1.directItems.count
            }) { mealsPath = NavigationPath([meal.id]) }
        case "run": tab = .shopping   // the root IS the checklist now
        default: break
        }
    }
}
