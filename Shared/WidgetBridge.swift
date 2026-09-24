import Foundation

/// Was das Widget anzeigt. Die App schreibt es nach jeder Änderung in den
/// gemeinsamen App-Group-Bereich; das Widget liest nur.
///
/// Das Widget öffnet die Datenbank bewusst nicht: So gibt es nie zwei Prozesse,
/// die gleichzeitig in Core Data und iCloud schreiben.
struct WidgetSnapshot: Codable, Equatable {
    var day: Date
    var kcalEaten: Double
    var kcalBudget: Double
    var carbs: Double
    var protein: Double
    var fat: Double
    var carbsTarget: Double
    var proteinTarget: Double
    var fatTarget: Double
    var fluidMl: Double
    var fluidGoalMl: Double
    var quickWaterMl: Double
    var updatedAt: Date

    var kcalLeft: Double { kcalBudget - kcalEaten }
    var fluidFraction: Double { fluidGoalMl > 0 ? fluidMl / fluidGoalMl : 0 }

    /// Leerer Zustand für einen neuen Tag, bevor die App wieder offen war.
    func resetForNewDay(_ day: Date) -> WidgetSnapshot {
        var copy = self
        copy.day = day
        copy.kcalEaten = 0
        copy.carbs = 0
        copy.protein = 0
        copy.fat = 0
        copy.fluidMl = 0
        return copy
    }

    static let placeholder = WidgetSnapshot(
        day: Date(), kcalEaten: 1210, kcalBudget: 2100, carbs: 140, protein: 70, fat: 45,
        carbsTarget: 236, proteinTarget: 131, fatTarget: 70, fluidMl: 1500, fluidGoalMl: 2600,
        quickWaterMl: 250, updatedAt: Date()
    )
}

/// Ein Glas Wasser, das im Widget angetippt wurde und auf die App wartet.
struct PendingWater: Codable, Equatable {
    var date: Date
    var ml: Double
}

enum WidgetBridge {
    static let appGroupIdentifier = "group.ch.hebera.buschper"
    static let widgetKind = "buschperWidget"
    private static let snapshotKey = "buschper.widget.snapshot"
    private static let pendingWaterKey = "buschper.widget.pendingWater"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    // MARK: Zusammenfassung

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    /// Die Zusammenfassung für heute. Stammt sie von gestern, beginnt der Tag bei 0.
    static func loadSnapshot(now: Date = Date(), calendar: Calendar = .current) -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        if calendar.isDate(snapshot.day, inSameDayAs: now) {
            return snapshot
        }
        return snapshot.resetForNewDay(calendar.startOfDay(for: now))
    }

    // MARK: Wasser aus dem Widget

    static func enqueueWater(ml: Double, at date: Date = Date()) {
        var pending = pendingWater()
        pending.append(PendingWater(date: date, ml: ml))
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: pendingWaterKey)
        }
        // Die Anzeige sofort nachführen, damit der Tipp sichtbar wirkt.
        if var snapshot = loadSnapshot(now: date) {
            snapshot.fluidMl += ml
            save(snapshot)
        }
    }

    static func pendingWater() -> [PendingWater] {
        guard let data = defaults.data(forKey: pendingWaterKey),
              let pending = try? JSONDecoder().decode([PendingWater].self, from: data)
        else { return [] }
        return pending
    }

    /// Holt alle wartenden Gläser ab und leert die Warteschlange.
    static func takePendingWater() -> [PendingWater] {
        let pending = pendingWater()
        defaults.removeObject(forKey: pendingWaterKey)
        return pending
    }
}
