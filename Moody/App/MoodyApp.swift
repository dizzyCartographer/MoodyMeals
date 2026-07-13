import SwiftUI

@main
struct MoodyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            // D-56: native basics shell. The sticker-aisle root lives at tag
            // `sticker-aisle-v1` (+ Attic/) if it's ever wanted back.
            AppTabView()
                .environmentObject(appState)
        }
    }
}
