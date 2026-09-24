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

    /// Zuletzt angezeigter Grundumsatz – für den Hinweis „Bedarf nöi berächnet“.
    var lastKnownBMR: Double {
        get { defaults.double(forKey: Key.lastKnownBMR) }
        set { set(newValue, for: Key.lastKnownBMR) }
    }
}
