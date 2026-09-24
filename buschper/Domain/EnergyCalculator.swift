import Foundation

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "Maa"
        case .female: return "Frou"
        }
    }
}

enum WeightGoal: String, Codable, CaseIterable, Identifiable {
    case lose
    case maintain
    case gain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lose: return "Abnäh"
        case .maintain: return "Haute"
        case .gain: return "Zuenäh"
        }
    }

    /// Vorgabe für den fixen Abschlag in kcal pro Tag (SPEC 4.4).
    var defaultOffset: Double {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 300
        }
    }
}

/// Bewegungsprofil. Wird nur gebraucht, wenn Apple Health bis Mittag keine
/// Aktivkalorien liefert (SPEC 4.3).
enum ActivityProfile: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case extreme

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .extreme: return 1.9
        }
    }

    var label: String {
        switch self {
        case .sedentary: return "Sitzend"
        case .light: return "Liecht aktiv"
        case .moderate: return "Mässig aktiv"
        case .active: return "Seer aktiv"
        case .extreme: return "Extrem aktiv"
        }
    }

    var explanation: String {
        switch self {
        case .sedentary: return "Büro, chuum Bewegig"
        case .light: return "1–3 × pro Wuche liecht Sport"
        case .moderate: return "3–5 × pro Wuche Sport"
        case .active: return "6–7 × pro Wuche Sport"
        case .extreme: return "Körperlech strängi Arbeit oder Training 2 × am Tag"
        }
    }
}

/// Kalorienbedarf – live, wie in der Befragung entschieden (Q10, Q24).
///
/// `Tagesbudget = Grundumsatz + bisher verbrannte Aktivkalorien + Ziel-Abschlag`
///
/// Das Budget wächst also über den Tag. Morgens ist es knapper, abends grösser.
enum EnergyCalculator {

    /// Ab dieser Stunde gilt ein Tag ohne Aktivdaten als „ohne Uhr“, und das
    /// Bewegungsprofil springt ein (Q37).
    static let fallbackHour = 12

    /// Absolute Untergrenze des Tagesbudgets.
    ///
    /// Die Spezifikation nannte ursprünglich den Grundumsatz als Untergrenze. Mit dem
    /// Live-Budget hätte das den Abschlag beim Abnehmen jeden Morgen aufgehoben,
    /// weil dann noch keine Aktivkalorien da sind. Deshalb gelten die üblichen
    /// Mindestwerte für eine Reduktionskost.
    static func minimumBudget(for sex: Sex) -> Double {
        switch sex {
        case .male: return 1500
        case .female: return 1200
        }
    }

    // MARK: - Grundumsatz

    static func age(birthDate: Date, on date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year], from: birthDate, to: date)
        return max(0, components.year ?? 0)
    }

    /// Mifflin-St Jeor.
    static func basalMetabolicRate(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    // MARK: - Tagesbudget

    struct Budget: Equatable {
        /// Grundumsatz für den ganzen Tag.
        var bmr: Double
        /// Aktivkalorien, die ins Budget einfliessen – gemessen oder geschätzt.
        var activeKcal: Double
        /// `true`, wenn die Aktivkalorien aus dem Bewegungsprofil geschätzt sind.
        var activeIsEstimate: Bool
        var goalOffset: Double
        /// Das Budget, gegen das gegessen wird.
        var total: Double
        /// `true`, wenn die Untergrenze gegriffen hat.
        var minimumApplied: Bool
    }

    /// - Parameters:
    ///   - measuredActiveKcal: Aktivkalorien aus Health für diesen Tag, `nil` wenn
    ///     Health nichts liefert oder keine Berechtigung besteht.
    ///   - dayStart: Beginn des betrachteten Tags.
    ///   - now: Jetzt. Liegt der Tag in der Vergangenheit, gilt er als abgeschlossen.
    static func budget(
        bmr: Double,
        measuredActiveKcal: Double?,
        activityProfile: ActivityProfile,
        goalOffset: Double,
        sex: Sex,
        dayStart: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Budget {
        let measured = measuredActiveKcal ?? 0
        var active = measured
        var isEstimate = false

        if measured <= 0 && fallbackApplies(dayStart: dayStart, now: now, calendar: calendar) {
            active = bmr * (activityProfile.factor - 1)
            isEstimate = true
        }

        let raw = bmr + active + goalOffset
        let minimum = minimumBudget(for: sex)
        let total = max(raw, minimum)

        return Budget(
            bmr: bmr,
            activeKcal: active,
            activeIsEstimate: isEstimate,
            goalOffset: goalOffset,
            total: total,
            minimumApplied: raw < minimum
        )
    }

    /// Ab 12:00 des Tages – oder für jeden vergangenen Tag – springt das
    /// Bewegungsprofil ein, wenn keine Aktivdaten da sind.
    static func fallbackApplies(dayStart: Date, now: Date, calendar: Calendar = .current) -> Bool {
        let startOfDay = calendar.startOfDay(for: dayStart)
        guard let noon = calendar.date(byAdding: .hour, value: fallbackHour, to: startOfDay) else {
            return false
        }
        return now >= noon
    }

    /// Hat sich der Grundumsatz so stark verändert, dass ein Hinweis angebracht ist?
    static func bmrChangeIsNotable(old: Double, new: Double) -> Bool {
        abs(old - new) > 20
    }
}
