import XCTest
import SwiftData
@testable import MoodyMeals

/// M0-1 acceptance: the test target builds and runs, and the SwiftData
/// container initializes and round-trips a model in memory.
final class SmokeTests: XCTestCase {

    func testTargetRuns() {
        XCTAssertTrue(true, "scaffold smoke test")
    }

    @MainActor
    func testInMemoryContainerRoundTrips() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppInfo.self, configurations: config)
        let context = container.mainContext

        context.insert(AppInfo(key: "scaffold", value: "ok"))
        let fetched = try context.fetch(FetchDescriptor<AppInfo>())

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.value, "ok")
    }
}
