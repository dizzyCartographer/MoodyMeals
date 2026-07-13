import SwiftUI

// D-56: the basics-first native shell. Standard tab bar — navigation is
// never a puzzle. Her palette survives as the accent; the sticker-aisle
// look is preserved at tag `sticker-aisle-v1` (Attic/ holds the screens).

struct AppTabView: View {
    @EnvironmentObject var appState: AppState

    enum Tab: String { case today, plan, meals, shopping, settings }
    @State private var tab: Tab = .today
    @State private var mealsPath: [UUID] = []

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
    private func applyDebugRoute() {
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "addmeal" {
            appState.createMeal(from: MealDraft(
                title: "Debug added meal", notes: "created by MOODY_DEMO=addmeal"))
        }
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "addrecipe",
           let target = appState.library.first(where: { $0.name == "Debug added meal" }),
           let recipeID = appState.addRecipe(toMeal: target.id,
                                             title: "Debug sauce", precise: false) {
            appState.addItem(.recipe(recipeID), name: "rice",
                             amount: 2, unit: "cups", perishabilityRaw: "pantry")
            appState.addItem(.recipe(recipeID), name: "debug spice blend",
                             amount: nil, unit: nil, perishabilityRaw: "pantry")
        }
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "completerun",
           let run = appState.runs.first {
            for item in run.items where !appState.isChecked(run.id, item.name) {
                appState.toggleChecked(run.id, item.name)
            }
            appState.completeRun(run.id)
        }
        // NB verification: a real assignment 16 days out — past any single week.
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "assignfuture",
           let meal = appState.library.first(where: { !$0.isRetired && !$0.isEatingOut }),
           let date = Calendar.current.date(byAdding: .day, value: 16, to: .now) {
            appState.assignMeal(meal.id, on: date, slotRaw: "dinner")
        }
        if ProcessInfo.processInfo.environment["MOODY_DEMO"] == "decide" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                appState.decideForMe()
            }
        }
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
            }) { mealsPath = [meal.id] }
        case "run": tab = .shopping   // the root IS the checklist now
        default: break
        }
    }
}
