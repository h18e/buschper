import Foundation
import Security

/// Kleiner Zugriff auf den Schlüsselbund – nur für das Open-Food-Facts-Passwort.
///
/// Bleibt auf diesem Gerät (nicht über iCloud synchronisiert), weil jede Person
/// selbst entscheidet, ob und mit welchem Konto sie beiträgt.
enum KeychainStore {
    private static let service = "ch.hebera.buschper.openfoodfacts"

    static func password(for account: String) -> String? {
        guard !account.isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func setPassword(_ password: String, for account: String) -> Bool {
        guard !account.isEmpty else { return false }
        removePasswords()
        guard !password.isEmpty else { return true }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(password.utf8),
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    /// Alle gespeicherten Open-Food-Facts-Passwörter entfernen (Konto gewechselt
    /// oder Mithelfen ausgeschaltet).
    static func removePasswords() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
