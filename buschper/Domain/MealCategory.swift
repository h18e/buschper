import Foundation

/// Mahlzeit-Kategorien (SPEC 5.2). Die Reihenfolge von `allCases` ist die
/// Reihenfolge im Tag.
enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case morningSnack
    case lunch
    case afternoonSnack
    case dinner
    case snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Zmorge"
        case .morningSnack: return "Znüni"
        case .lunch: return "Zmittag"
        case .afternoonSnack: return "Zvieri"
        case .dinner: return "Znacht"
        case .snack: return "Snack"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .morningSnack: return "leaf.fill"
        case .lunch: return "sun.max.fill"
        case .afternoonSnack: return "cup.and.saucer.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }

    /// Minuten seit Mitternacht, ab denen eine Kategorie vorgeschlagen wird.
    private static let windows: [(start: Int, end: Int, category: MealCategory)] = [
        (5 * 60, 9 * 60 + 30, .breakfast),
        (9 * 60 + 30, 11 * 60, .morningSnack),
        (11 * 60, 14 * 60, .lunch),
        (14 * 60, 17 * 60 + 30, .afternoonSnack),
        (17 * 60 + 30, 22 * 60, .dinner)
    ]

    /// Vorschlag aus der Uhrzeit. Ausserhalb aller Fenster: Snack.
    static func suggested(for date: Date, calendar: Calendar = .current) -> MealCategory {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return windows.first { minutes >= $0.start && minutes < $0.end }?.category ?? .snack
    }

    /// Feste Uhrzeit für geplante Einträge (SPEC 5.2). Snacks werden nicht
    /// geplant und haben keine.
    var plannedTime: (hour: Int, minute: Int)? {
        switch self {
        case .breakfast: return (7, 0)
        case .morningSnack: return (9, 0)
        case .lunch: return (12, 0)
        case .afternoonSnack: return (15, 0)
        case .dinner: return (19, 0)
        case .snack: return nil
        }
    }

    /// Ab so vielen Minuten Vorlauf gilt ein Eintrag von heute als geplant.
    static let planningLeadMinutes = 30

    /// Zeitpunkt für einen geplanten Eintrag dieser Kategorie am Tag von `date`.
    /// `nil`, wenn nicht geplant wird: Snack, ein vergangener Tag oder heute
    /// eine Zeit, die schon (fast) vorbei ist – dann bleibt die Uhrzeit.
    func plannedTimestamp(on date: Date, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let time = plannedTime,
              let planned = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: date)
        else { return nil }
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        if day > today { return planned }
        if day == today, planned.timeIntervalSince(now) > Double(Self.planningLeadMinutes * 60) { return planned }
        return nil
    }

    /// Wird eine Mahlzeit dieser Kategorie als Znacht gewertet (Schlafanalyse)?
    var isDinner: Bool { self == .dinner }
}
