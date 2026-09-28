import CoreData
import Foundation
import SwiftUI

/// Gerätelokale Einstellungen.
///
/// Bewusst **nicht** in iCloud: Erinnerungen plant jedes Gerät selbst, und die
/// Geräte-Kennung für Health-Einträge ist per Definition pro Gerät. Alles, was
/// dich als Person betrifft (Ziele, Dashboard, Schwellen), liegt im Profil und
/// gleicht über iCloud ab.
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private enum Key {
        static let deviceId = "buschper.deviceId"
        static let usesOpenFoodFacts = "buschper.usesOpenFoodFacts"
        static let waterReminderEnabled = "buschper.waterReminderEnabled"
        static let waterReminderStartHour = "buschper.waterReminderStartHour"
        static let waterReminderEndHour = "buschper.waterReminderEndHour"
        static let waterReminderIntervalHours = "buschper.waterReminderIntervalHours"
        static let morningCheckInEnabled = "buschper.morningCheckInEnabled"
        static let morningCheckInHour = "buschper.morningCheckInHour"
        static let morningCheckInMinute = "buschper.morningCheckInMinute"
        static let quickWaterMl = "buschper.quickWaterMl"
        static let lastKnownBMR = "buschper.lastKnownBMR"
        static let drinkDefaults = "buschper.drinkDefaults"
        static let contributesToOpenFoodFacts = "buschper.contributesToOpenFoodFacts"
        static let openFoodFactsUserId = "buschper.openFoodFactsUserId"
        static let openFoodFactsAppUUID = "buschper.openFoodFactsAppUUID"
        static let openFoodFactsLastResult = "buschper.openFoodFactsLastResult"
    }

    private let defaults: UserDefaults

    /// Die Einstellungen liegen im App-Group-Bereich, damit das Widget dieselbe
    /// Geräte-Kennung und dieselbe Schnelltasten-Menge sieht wie die App.
    static let sharedDefaults: UserDefaults =
        UserDefaults(suiteName: PersistenceController.appGroupIdentifier) ?? .standard

    init(defaults: UserDefaults = AppPreferences.sharedDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.usesOpenFoodFacts: true,
            Key.waterReminderEnabled: false,
            Key.waterReminderStartHour: 9,
            Key.waterReminderEndHour: 19,
            Key.waterReminderIntervalHours: 2,
            Key.morningCheckInEnabled: false,
            Key.morningCheckInHour: 7,
            Key.morningCheckInMinute: 30,
            Key.quickWaterMl: 250.0
        ])
    }

    private func set<T>(_ value: T, for key: String) {
        objectWillChange.send()
        defaults.set(value, forKey: key)
    }

    /// Kennung dieses Geräts. Health-Einträge werden nur auf dem Gerät geschrieben,
    /// auf dem sie erfasst wurden (SPEC 8.3).
    var deviceId: String {
        if let existing = defaults.string(forKey: Key.deviceId), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        defaults.set(new, forKey: Key.deviceId)
        return new
    }

    /// Darf bei Suche und Scan Open Food Facts gefragt werden?
    var usesOpenFoodFacts: Bool {
        get { defaults.bool(forKey: Key.usesOpenFoodFacts) }
        set { set(newValue, for: Key.usesOpenFoodFacts) }
    }

    var waterReminderEnabled: Bool {
        get { defaults.bool(forKey: Key.waterReminderEnabled) }
        set { set(newValue, for: Key.waterReminderEnabled) }
    }

    var waterReminderStartHour: Int {
        get { defaults.integer(forKey: Key.waterReminderStartHour) }
        set { set(min(23, max(0, newValue)), for: Key.waterReminderStartHour) }
    }

    var waterReminderEndHour: Int {
        get { defaults.integer(forKey: Key.waterReminderEndHour) }
        set { set(min(23, max(0, newValue)), for: Key.waterReminderEndHour) }
    }

    var waterReminderIntervalHours: Int {
        get { defaults.integer(forKey: Key.waterReminderIntervalHours) }
        set { set(min(6, max(1, newValue)), for: Key.waterReminderIntervalHours) }
    }

    var morningCheckInEnabled: Bool {
        get { defaults.bool(forKey: Key.morningCheckInEnabled) }
        set { set(newValue, for: Key.morningCheckInEnabled) }
    }

    var morningCheckInHour: Int {
        get { defaults.integer(forKey: Key.morningCheckInHour) }
        set { set(min(23, max(0, newValue)), for: Key.morningCheckInHour) }
    }

    var morningCheckInMinute: Int {
        get { defaults.integer(forKey: Key.morningCheckInMinute) }
        set { set(min(59, max(0, newValue)), for: Key.morningCheckInMinute) }
    }

    /// Menge der Schnelltaste auf dem Dashboard und im Widget.
    var quickWaterMl: Double {
        get { defaults.double(forKey: Key.quickWaterMl) }
        set { set(min(2000, max(50, newValue)), for: Key.quickWaterMl) }
    }

    /// Zuletzt verwendete Werte pro Getränketyp – z. B. dein Kaffee mit 2 dl und
    /// eigenen Nährwerten. Ersetzen die Richtwerte beim nächsten Mal.
    func drinkDefault(for type: DrinkType) -> DrinkDefault? {
        storedDrinkDefaults()[type.rawValue]
    }

    func setDrinkDefault(_ value: DrinkDefault, for type: DrinkType) {
        var all = storedDrinkDefaults()
        all[type.rawValue] = value
        if let data = try? JSONEncoder().encode(all) {
            set(data, for: Key.drinkDefaults)
        }
    }

    func resetDrinkDefault(for type: DrinkType) {
        var all = storedDrinkDefaults()
        all[type.rawValue] = nil
        if let data = try? JSONEncoder().encode(all) {
            set(data, for: Key.drinkDefaults)
        }
    }

    private func storedDrinkDefaults() -> [String: DrinkDefault] {
        guard let data = defaults.data(forKey: Key.drinkDefaults),
              let decoded = try? JSONDecoder().decode([String: DrinkDefault].self, from: data)
        else { return [:] }
        return decoded
    }

    /// Zuletzt angezeigter Grundumsatz – für den Hinweis „Bedarf nöi berächnet“.
    var lastKnownBMR: Double {
        get { defaults.double(forKey: Key.lastKnownBMR) }
        set { set(newValue, for: Key.lastKnownBMR) }
    }

    // MARK: - Open Food Facts mithelfen (freiwillig, pro Gerät)

    /// Neue und ergänzte Produkte mit Barcode an Open Food Facts schicken.
    /// Standard aus – jede Person entscheidet selbst.
    var contributesToOpenFoodFacts: Bool {
        get { defaults.bool(forKey: Key.contributesToOpenFoodFacts) }
        set { set(newValue, for: Key.contributesToOpenFoodFacts) }
    }

    /// Benutzername bei Open Food Facts (nicht die E-Mail). Das Passwort liegt
    /// im Schlüsselbund, nicht hier.
    var openFoodFactsUserId: String {
        get { defaults.string(forKey: Key.openFoodFactsUserId) ?? "" }
        set { set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: Key.openFoodFactsUserId) }
    }

    /// Zufällige Kennung dieser Installation, von Open Food Facts erbeten, damit
    /// Moderatoren einzelne Beiträge zuordnen können. Enthält nichts über dich.
    var openFoodFactsAppUUID: String {
        if let existing = defaults.string(forKey: Key.openFoodFactsAppUUID), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        defaults.set(new, forKey: Key.openFoodFactsAppUUID)
        return new
    }

    /// Ergebnis des letzten Beitrags, für die Anzeige in den Einstellungen.
    var openFoodFactsLastResult: String {
        get { defaults.string(forKey: Key.openFoodFactsLastResult) ?? "" }
        set { set(newValue, for: Key.openFoodFactsLastResult) }
    }
}

/// Gemerkte Werte eines Getränketyps.
struct DrinkDefault: Codable, Equatable {
    var volumeMl: Double
    var abvPercent: Double
    var countsAsFluid: Bool
    var per100ml: Nutrients
}
