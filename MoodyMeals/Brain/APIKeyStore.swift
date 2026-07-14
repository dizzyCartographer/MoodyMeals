import Foundation
import Security

// ── D-63: where MoodyBrain's Anthropic key actually lives on a real
// phone ── An installed TestFlight/App Store build has no usable
// "environment variable" (that's an Xcode-debug-only convenience, gone
// the moment the app isn't launched from Xcode) — Keychain, entered
// once in Settings, is the only path that works after normal install.
// Never committed: this is runtime, user-entered, on-device only.

enum APIKeyStore {
    private static let service = "com.mariayarley.Moody.anthropic"
    private static let account = "ANTHROPIC_API_KEY"

    /// The env var wins when present — keeps the Xcode-scheme convenience
    /// for local dev/simulator runs; Keychain is what real devices use.
    static var anthropicAPIKey: String? {
        if let fromEnv = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !fromEnv.isEmpty {
            return fromEnv
        }
        return readFromKeychain()
    }

    /// True only when a Keychain-stored key exists — the Settings screen's
    /// own "is it set" check shouldn't read as configured just because a
    /// developer happens to be running from Xcode with the env var set.
    static var hasKeychainKey: Bool {
        readFromKeychain() != nil
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clear() }
        let query = baseQuery()
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(trimmed.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func clear() -> Bool {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func readFromKeychain() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
