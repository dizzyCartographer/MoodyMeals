import SwiftUI
import SwiftData

@main
struct MoodyMealsApp: App {
    @State private var calendarSync = CalendarSyncService(store: EventKitCalendarStore())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(calendarSync)
        }
        .modelContainer(for: AppSchema.models)
    }
}
