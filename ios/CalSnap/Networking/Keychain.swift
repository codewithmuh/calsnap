import Foundation
import Security

/// Tiny Keychain wrapper for JWT storage.
enum Keychain {
    private static let service = "com.codewithmuh.calsnap.tokens"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // Convenience for the two tokens we store.
    static var accessToken: String? {
        get { get("access") }
        set { newValue.map { set($0, for: "access") } ?? delete("access") }
    }

    static var refreshToken: String? {
        get { get("refresh") }
        set { newValue.map { set($0, for: "refresh") } ?? delete("refresh") }
    }

    static func clear() {
        delete("access")
        delete("refresh")
    }
}
