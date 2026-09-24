import Foundation

/// Eine Nacht, wie sie aus Apple Health zusammengesetzt wird.
struct SleepNight: Equatable {
    /// Einschlafzeitpunkt (Beginn der ersten Schlafphase).
    var sleepOnset: Date
    /// Aufwachzeitpunkt (Ende der letzten Schlafphase).
    var wake: Date
    /// Tatsächliche Schlafzeit in Minuten (Kern + Tief + REM oder „geschlafen“).
    var asleepMinutes: Double
    /// `nil`, wenn die Quelle keine Phasen liefert (z. B. nur iPhone).
    var deepMinutes: Double?
    var remMinutes: Double?
    var coreMinutes: Double?
    /// Wachzeit zwischen Einschlafen und Aufwachen.
    var awakeMinutes: Double

    var hasStages: Bool { deepMinutes != nil && remMinutes != nil }
}

/// Punkte je Komponente. Bei fehlenden Phasen sind `deep` und `rem` `nil`.
struct SleepScoreComponents: Codable, Equatable {
    var duration: Double
    var deep: Double?
    var rem: Double?
    var awake: Double
    var regularity: Double?
    /// 0–100.
    var total: Double
}

/// Eigener Schlafscore 0–100 (SPEC 11.2).
///
/// Jede Komponente liefert einen Anteil zwischen 0 und 1, der mit ihrem Gewicht
/// multipliziert wird. Fehlt eine Komponente (keine Phasen, noch keine Vorgeschichte
/// für die Regelmässigkeit), werden die übrigen Gewichte auf 100 hochgerechnet.
enum SleepScore {

    enum Weight {
        static let duration = 40.0
        static let deep = 20.0
        static let rem = 15.0
        static let awake = 15.0
        static let regularity = 10.0
    }

    // MARK: - Schwellen

    /// Unter 50 % des Schlafziels gibt es für die Dauer keine Punkte mehr.
    static let durationZeroShare = 0.5
    /// Tiefschlaf: volle Punkte ab 13 %, keine bis 5 %.
    static let deepFullPercent = 13.0
    static let deepZeroPercent = 5.0
    /// REM: volle Punkte ab 20 %, keine bis 8 %.
    static let remFullPercent = 20.0
    static let remZeroPercent = 8.0
    /// Wach nach dem Einschlafen: volle Punkte bis 10 min, keine ab 60 min.
    static let awakeFullMinutes = 10.0
    static let awakeZeroMinutes = 60.0
    /// Abweichung der Einschlafzeit vom Median: voll bis 15 min, keine ab 90 min.
    static let regularityFullMinutes = 15.0
    static let regularityZeroMinutes = 90.0

    /// - Parameter medianOnsetSinceNoon: Median der Einschlafzeiten der letzten
    ///   14 Nächte in `DayMath.minutesSinceNoon`. `nil` ohne Vorgeschichte.
    static func score(
        night: SleepNight,
        sleepGoalMinutes: Double,
        medianOnsetSinceNoon: Double?,
        calendar: Calendar = .current
    ) -> SleepScoreComponents {
        let goal = max(1, sleepGoalMinutes)
        let durationShare = rise(night.asleepMinutes / goal, zeroAt: durationZeroShare, fullAt: 1)

        var deepShare: Double?
        var remShare: Double?
        if let deep = night.deepMinutes, let rem = night.remMinutes, night.asleepMinutes > 0 {
            // Über den Zielbereich hinaus gibt es keinen Abzug: Zu viel Tief- oder
            // REM-Schlaf ist kein Befund, den ein Tracker werten sollte.
            deepShare = rise(deep / night.asleepMinutes * 100, zeroAt: deepZeroPercent, fullAt: deepFullPercent)
            remShare = rise(rem / night.asleepMinutes * 100, zeroAt: remZeroPercent, fullAt: remFullPercent)
        }

        let awakeShare = fall(night.awakeMinutes, fullUntil: awakeFullMinutes, zeroFrom: awakeZeroMinutes)

        var regularityShare: Double?
        if let median = medianOnsetSinceNoon {
            let onset = DayMath.minutesSinceNoon(night.sleepOnset, calendar: calendar)
            regularityShare = fall(abs(onset - median), fullUntil: regularityFullMinutes, zeroFrom: regularityZeroMinutes)
        }

        var earned = durationShare * Weight.duration + awakeShare * Weight.awake
        var possible = Weight.duration + Weight.awake
        if let deepShare {
            earned += deepShare * Weight.deep
            possible += Weight.deep
        }
        if let remShare {
            earned += remShare * Weight.rem
            possible += Weight.rem
        }
        if let regularityShare {
            earned += regularityShare * Weight.regularity
            possible += Weight.regularity
        }

        let total = possible > 0 ? earned / possible * 100 : 0

        return SleepScoreComponents(
            duration: durationShare * Weight.duration,
            deep: deepShare.map { $0 * Weight.deep },
            rem: remShare.map { $0 * Weight.rem },
            awake: awakeShare * Weight.awake,
            regularity: regularityShare.map { $0 * Weight.regularity },
            total: (total * 10).rounded() / 10
        )
    }

    /// 0 bis `zeroAt`, linear steigend bis `fullAt`, danach 1.
    static func rise(_ value: Double, zeroAt: Double, fullAt: Double) -> Double {
        if value <= zeroAt { return 0 }
        if value >= fullAt { return 1 }
        return (value - zeroAt) / (fullAt - zeroAt)
    }

    /// 1 bis `fullUntil`, linear fallend bis `zeroFrom`, danach 0.
    static func fall(_ value: Double, fullUntil: Double, zeroFrom: Double) -> Double {
        if value <= fullUntil { return 1 }
        if value >= zeroFrom { return 0 }
        return 1 - (value - fullUntil) / (zeroFrom - fullUntil)
    }
}

// MARK: - Schlechte Nacht

/// Schwellen für „schlechte Nacht“ (SPEC 11.4), alle einstellbar.
struct BadNightRules: Codable, Equatable {
    /// Score darunter ist schlecht.
    var absoluteThreshold: Double = 60
    /// So viele Punkte unter dem 30-Tage-Schnitt ist schlecht.
    var relativeDrop: Double = 10
    /// Morgen-Einschätzung bis und mit diesem Wert ist schlecht.
    var badRatingMax: Int = 2

    static let standard = BadNightRules()
}

enum BadNightReason: String, Codable, CaseIterable {
    case lowScore
    case belowAverage
    case feltBad

    var label: String {
        switch self {
        case .lowScore: return "Score tief"
        case .belowAverage: return "Dütlech under dym Schnitt"
        case .feltBad: return "Schlächt gfüeut"
        }
    }
}

enum NightClassifier {
    /// Gründe, warum eine Nacht als schlecht gilt. Leer heisst: nicht schlecht.
    static func reasons(
        score: Double,
        average30: Double?,
        rating: Int?,
        rules: BadNightRules
    ) -> [BadNightReason] {
        var result: [BadNightReason] = []
        if score < rules.absoluteThreshold {
            result.append(.lowScore)
        }
        if let average30, score <= average30 - rules.relativeDrop {
            result.append(.belowAverage)
        }
        if let rating, rating > 0, rating <= rules.badRatingMax {
            result.append(.feltBad)
        }
        return result
    }

    static func isBad(score: Double, average30: Double?, rating: Int?, rules: BadNightRules) -> Bool {
        !reasons(score: score, average30: average30, rating: rating, rules: rules).isEmpty
    }
}
