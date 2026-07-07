import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Plan", systemImage: "calendar") { WeekPlanView() }
            Tab("Meals", systemImage: "fork.knife") { MealListView() }
            Tab("Recipes", systemImage: "list.bullet.rectangle") { RecipeListView() }
        }
        .task {
            try? SeedData.loadIfNeeded(into: modelContext)
        }
    }
}

#Preview {
    ContentView()
}
