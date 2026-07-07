import SwiftUI
import SwiftData

@main
struct MoodyMealsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: AppInfo.self)
    }
}
