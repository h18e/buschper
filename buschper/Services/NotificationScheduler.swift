import Foundation
import UserNotifications

/// Lokale Erinnerungen, beide standardmässig aus (SPEC 15).
///
/// - **Trinke:** in festen Abständen zwischen Start- und Endzeit, aber heute nur,
///   solange das Tagesziel noch nicht erreicht ist. Morgen immer – der Plan wird
///   bei jedem Öffnen und jeder Änderung neu gemacht.
/// - **Morge-Iischätzig:** täglich zur gewählten Zeit.
@MainActor
final class NotificationScheduler {
    static let waterPrefix = "buschper.water."
    static let morningIdentifier = "buschper.morning"
    static let openSleepKey = "openSleep"

    private let store: DataStore
    private let preferences: AppPreferences
    private let center = UNUserNotificationCenter.current()

    init(store: DataStore, preferences: AppPreferences) {
        self.store = store
        self.preferences = preferences
    }

    /// Fragt nach der Erlaubnis. `false`, wenn abgelehnt.
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func refresh(fluidMl: Double? = nil, fluidGoalMl: Double? = nil) async {
        await scheduleWater(fluidMl: fluidMl, goalMl: fluidGoalMl)
        await scheduleMorning()
    }

    // MARK: - Trinken

    private func scheduleWater(fluidMl: Double?, goalMl: Double?) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.waterPrefix) })
        guard preferences.waterReminderEnabled else { return }

        let calendar = Calendar.current
        let now = Date()
        // Stand von heute: aus der Widget-Zusammenfassung, die gerade vorher
        // nachgeführt wurde, sonst direkt aus den Getränken.
        let snapshot = WidgetBridge.loadSnapshot(now: now)
        let drunk = fluidMl ?? snapshot?.fluidMl ?? store.drinks(on: now).reduce(0) { $0 + $1.fluidMl }
        let goal = goalMl ?? snapshot?.fluidGoalMl
        let reachedToday = goal.map { $0 > 0 && drunk >= $0 } ?? false

        let start = preferences.waterReminderStartHour
        let end = max(start, preferences.waterReminderEndHour)
        let step = max(1, preferences.waterReminderIntervalHours)

        for dayOffset in 0...1 {
            if dayOffset == 0 && reachedToday { continue }
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            for hour in stride(from: start, through: end, by: step) {
                guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Zyt für es Glas"
                content.body = dayOffset == 0 && drunk > 0
                    ? "Bis jetz \(NumberText.volume(drunk)). Es Glas Wasser tuet guet."
                    : "Es Glas Wasser tuet guet."
                content.sound = .default
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let request = UNNotificationRequest(
                    identifier: "\(Self.waterPrefix)\(dayOffset)-\(hour)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    // MARK: - Morgen-Einschätzung

    private func scheduleMorning() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningIdentifier])
        guard preferences.morningCheckInEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Guete Morge"
        content.body = "Wie hesch gschlafe? Tipp für d Stärn."
        content.sound = .default
        content.userInfo = [Self.openSleepKey: true]
        var components = DateComponents()
        components.hour = preferences.morningCheckInHour
        components.minute = preferences.morningCheckInMinute
        let request = UNNotificationRequest(
            identifier: Self.morningIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }
}

extension Notification.Name {
    /// Eine Mitteilung möchte den Schlaf-Tab öffnen.
    static let buschperOpenSleep = Notification.Name("buschper.openSleep")
}
