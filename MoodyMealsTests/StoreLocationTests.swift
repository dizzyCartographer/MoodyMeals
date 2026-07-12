import XCTest
@testable import MoodyEngine

/// U-1 acceptance: the store moves into the App Group container and existing
/// data survives the move. All paths injected — temp dirs, no real containers.
final class StoreLocationTests: XCTestCase {

    private var root: URL!
    private var group: URL!
    private var legacy: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory
            .appendingPathComponent("StoreLocationTests-\(UUID().uuidString)")
        group = root.appendingPathComponent("group", isDirectory: true)
        legacy = root.appendingPathComponent("legacy", isDirectory: true)
        try fm.createDirectory(at: group, withIntermediateDirectories: true)
        try fm.createDirectory(at: legacy, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    private func legacyStore(_ suffix: String = "") -> URL {
        URL(fileURLWithPath: legacy.appendingPathComponent(StoreLocation.storeFileName).path + suffix)
    }
    private func groupStore(_ suffix: String = "") -> URL {
        URL(fileURLWithPath: group.appendingPathComponent("Store/\(StoreLocation.storeFileName)").path + suffix)
    }

    func test_U1_freshInstall_resolvesToGroupContainer() {
        let url = StoreLocation.resolve(groupContainer: group, legacyDirectory: legacy)
        XCTAssertEqual(url, groupStore())
        XCTAssertFalse(fm.fileExists(atPath: url.path),
                       "resolve never fabricates a store — SwiftData creates it")
    }

    func test_U1_legacyStoreMigrates_allFilesAndBytesSurvive() throws {
        try Data("base".utf8).write(to: legacyStore())
        try Data("shm".utf8).write(to: legacyStore("-shm"))
        try Data("wal".utf8).write(to: legacyStore("-wal"))

        let url = StoreLocation.resolve(groupContainer: group, legacyDirectory: legacy)

        XCTAssertEqual(url, groupStore())
        XCTAssertEqual(try Data(contentsOf: groupStore()), Data("base".utf8))
        XCTAssertEqual(try Data(contentsOf: groupStore("-shm")), Data("shm".utf8))
        XCTAssertEqual(try Data(contentsOf: groupStore("-wal")), Data("wal".utf8),
                       "the WAL carries un-checkpointed rows — it must travel")
        XCTAssertFalse(fm.fileExists(atPath: legacyStore().path), "move, not copy")
    }

    func test_U1_partialSidecars_onlyExistingFilesMove() throws {
        try Data("base".utf8).write(to: legacyStore())
        try Data("wal".utf8).write(to: legacyStore("-wal"))
        // no -shm on disk

        let url = StoreLocation.resolve(groupContainer: group, legacyDirectory: legacy)

        XCTAssertEqual(url, groupStore())
        XCTAssertTrue(fm.fileExists(atPath: groupStore("-wal").path))
        XCTAssertFalse(fm.fileExists(atPath: groupStore("-shm").path))
    }

    func test_U1_groupContainerUnavailable_staysLegacy_filesUntouched() throws {
        try Data("base".utf8).write(to: legacyStore())

        let url = StoreLocation.resolve(groupContainer: nil, legacyDirectory: legacy)

        XCTAssertEqual(url, legacyStore())
        XCTAssertEqual(try Data(contentsOf: legacyStore()), Data("base".utf8))
    }

    func test_U1_bothExist_groupWins_legacyLeftForRecovery() throws {
        try fm.createDirectory(at: group.appendingPathComponent("Store"),
                               withIntermediateDirectories: true)
        try Data("group-data".utf8).write(to: groupStore())
        try Data("legacy-data".utf8).write(to: legacyStore())

        let url = StoreLocation.resolve(groupContainer: group, legacyDirectory: legacy)

        XCTAssertEqual(url, groupStore())
        XCTAssertEqual(try Data(contentsOf: groupStore()), Data("group-data".utf8),
                       "an already-migrated store is never clobbered")
        XCTAssertTrue(fm.fileExists(atPath: legacyStore().path),
                      "conflicting legacy files stay put for manual recovery")
    }

    func test_U1_secondLaunch_resolvesSameURL_noMigrationReplay() throws {
        try Data("base".utf8).write(to: legacyStore())
        let first = StoreLocation.resolve(groupContainer: group, legacyDirectory: legacy)
        let second = StoreLocation.resolve(groupContainer: group, legacyDirectory: legacy)
        XCTAssertEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: second), Data("base".utf8))
    }

    func test_U1_allFiles_coversBaseAndSidecars() {
        let files = StoreLocation.allFiles(of: groupStore()).map(\.lastPathComponent)
        XCTAssertEqual(files, ["MoodyEngine.store",
                               "MoodyEngine.store-shm",
                               "MoodyEngine.store-wal"])
    }
}
