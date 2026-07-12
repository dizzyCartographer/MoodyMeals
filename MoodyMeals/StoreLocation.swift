import Foundation

/// Where the SwiftData store lives, plus the one-time move into the App Group
/// container (U-1 / unification P2). Widgets never open the store — they read
/// the MoodySnapshot projection — so the move is about giving the app's data a
/// stable shared home before any tester carries real data.
///
/// Same never-crash contract as the app bootstrap:
/// - Fresh install → the App Group container.
/// - A store in the legacy Application Support home is MOVED; data survives.
/// - Group container unavailable (no entitlement: engine tests, CI) → stay in
///   the legacy home. Never fail, never lose data.
/// - Both exist (interrupted move, downgrade) → the group copy wins and the
///   legacy files stay untouched for manual recovery. Never clobber.
public enum StoreLocation {
    public static let storeFileName = "MoodyEngine.store"
    /// SQLite sidecars that must travel with the base file — a WAL left behind
    /// is silent data loss (un-checkpointed rows live there).
    static let sidecarSuffixes = ["-shm", "-wal"]

    /// The store's home inside a group container / a legacy directory.
    /// Exposed so reset paths can name both homes without re-running resolve.
    public static func groupStoreURL(container: URL) -> URL {
        container.appendingPathComponent("Store", isDirectory: true)
            .appendingPathComponent(storeFileName)
    }
    public static func legacyStoreURL(directory: URL) -> URL {
        directory.appendingPathComponent(storeFileName)
    }

    /// Resolve the active store URL, migrating legacy→group if needed.
    /// Paths are injected so tests run against temp directories.
    public static func resolve(
        groupContainer: URL?,
        legacyDirectory: URL,
        fileManager fm: FileManager = .default
    ) -> URL {
        let legacyURL = legacyStoreURL(directory: legacyDirectory)
        guard let groupContainer else { return legacyURL }

        let groupURL = groupStoreURL(container: groupContainer)
        try? fm.createDirectory(at: groupURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)

        if fm.fileExists(atPath: groupURL.path) { return groupURL }
        guard fm.fileExists(atPath: legacyURL.path) else { return groupURL }

        // Copy-then-delete, all files or none: a half-moved store must never
        // become the one SwiftData opens.
        let pairs = filePairs(from: legacyURL, to: groupURL)
            .filter { fm.fileExists(atPath: $0.from.path) }
        var landed: [URL] = []
        for pair in pairs {
            do {
                try fm.copyItem(at: pair.from, to: pair.to)
                landed.append(pair.to)
            } catch {
                landed.forEach { try? fm.removeItem(at: $0) }
                return legacyURL
            }
        }
        pairs.forEach { try? fm.removeItem(at: $0.from) }
        return groupURL
    }

    /// Every on-disk footprint of a store (base + sidecars) — reset wipes these.
    public static func allFiles(of url: URL) -> [URL] {
        [url] + sidecarSuffixes.map { URL(fileURLWithPath: url.path + $0) }
    }

    private static func filePairs(from: URL, to: URL) -> [(from: URL, to: URL)] {
        zip(allFiles(of: from), allFiles(of: to)).map { ($0, $1) }
    }
}
