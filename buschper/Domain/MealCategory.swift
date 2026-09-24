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

    /// Wird eine Mahlzeit dieser Kategorie als Znacht gewertet (Schlafanalyse)?
    var isDinner: Bool { self == .dinner }
}
