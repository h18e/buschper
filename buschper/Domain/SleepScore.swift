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

/// Punkte je Komponente. Bei fehlenden Phasen sind `deep`, `rem` und `light` `nil`.
struct SleepScoreComponents: Codable, Equatable {
    var duration: Double
    var deep: Double?
    var rem: Double?
    /// Leichtschlaf (Apple: „Kern“). Fehlt in Auswertungen vor Testrunde 11.
    var light: Double? = nil
    var awake: Double
    var regularity: Double?
    /// 0–100.
    var total: Double
}

/// Zielbereich in Prozent der Nacht: volle Punkte zwischen `low` und `high`,
/// linear weniger bis 0 bei `zeroBelow` bzw. `zeroAbove`.
struct SleepBand: Equatable {
    var zeroBelow: Double
    var low: Double
    var high: Double
    var zeroAbove: Double

    func share(_ percent: Double) -> Double {
        if percent < low { return SleepScore.rise(percent, zeroAt: zeroBelow, fullAt: low) }
        if percent > high { return SleepScore.fall(percent, fullUntil: high, zeroFrom: zeroAbove) }
        return 1
    }
}

/// Eigener Schlafscore 0–100 (SPEC 11.2, Richtwerte aus Testrunde 11).
///
/// Die Phasen werden als Anteil der **ganzen Nacht** (Einschlafen bis Aufwachen,
/// Wachphasen eingeschlossen) gewertet – dieselben Prozente wie im Phasenbalken.
/// Richtwerte für einen ausgewogenen Schlaf:
///
/// | Phase | Ziel |
/// |---|---|
/// | Leichtschlaf | 50–60 % |
/// | Tiefschlaf | 15–25 % |
/// | REM | 20–25 % |
/// | Wach | unter 5 % |
///
/// Jede Komponente liefert einen Anteil zwischen 0 und 1, der mit ihrem Gewicht
/// multipliziert wird. Fehlt eine Komponente (keine Phasen, noch keine Vorgeschichte
/// für die Regelmässigkeit), werden die übrigen Gewichte auf 100 hochgerechnet.
enum SleepScore {

    enum Weight {
        static let duration = 35.0
        static let deep = 20.0
        static let rem = 15.0
        static let light = 10.0
        static let awake = 10.0
        static let regularity = 10.0
    }

    // MARK: - Schwellen

    /// Unter 50 % des Schlafziels gibt es für die Dauer keine Punkte mehr.
    static let durationZeroShare = 0.5
    static let lightBand = SleepBand(zeroBelow: 30, low: 50, high: 60, zeroAbove: 80)
    static let deepBand = SleepBand(zeroBelow: 5, low: 15, high: 25, zeroAbove: 40)
    static let remBand = SleepBand(zeroBelow: 8, low: 20, high: 25, zeroAbove: 40)
    /// Wach: volle Punkte bis 5 % der Nacht, keine ab 20 %.
    static let awakeFullPercent = 5.0
    static let awakeZeroPercent = 20.0
    /// Abweichung der Einschlafzeit vom Median: voll bis 15 min, keine ab 90 min.
    static let regularityFullMinutes = 15.0
    static let regularityZeroMinutes = 90.0

    /// Ganze Nacht in Minuten: Schlaf plus Wachphasen dazwischen.
    static func nightMinutes(_ night: SleepNight) -> Double {
        night.asleepMinutes + night.awakeMinutes
    }

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
        let total = nightMinutes(night)

        var deepShare: Double?
        var remShare: Double?
        var lightShare: Double?
        if let deep = night.deepMinutes, let rem = night.remMinutes, total > 0 {
            deepShare = deepBand.share(deep / total * 100)
            remShare = remBand.share(rem / total * 100)
            let light = night.coreMinutes ?? max(0, night.asleepMinutes - deep - rem)
            lightShare = lightBand.share(light / total * 100)
        }

        let awakePercent = total > 0 ? night.awakeMinutes / total * 100 : 0
        let awakeShare = fall(awakePercent, fullUntil: awakeFullPercent, zeroFrom: awakeZeroPercent)

        var regularityShare: Double?
        if let median = medianOnsetSinceNoon {
            let onset = DayMath.minutesSinceNoon(night.sleepOnset, calendar: calendar)
            regularityShare = fall(abs(onset - median), fullUntil: regularityFullMinutes, zeroFrom: regularityZeroMinutes)
        }

        var earned = durationShare * Weight.duration + awakeShare * Weight.awake
        var possible = Weight.duration + Weight.awake
        for (share, weight) in [(deepShare, Weight.deep), (remShare, Weight.rem),
                                (lightShare, Weight.light), (regularityShare, Weight.regularity)] {
            guard let share else { continue }
            earned += share * weight
            possible += weight
        }

        let result = possible > 0 ? earned / possible * 100 : 0

        return SleepScoreComponents(
            duration: durationShare * Weight.duration,
            deep: deepShare.map { $0 * Weight.deep },
            rem: remShare.map { $0 * Weight.rem },
            light: lightShare.map { $0 * Weight.light },
            awake: awakeShare * Weight.awake,
            regularity: regularityShare.map { $0 * Weight.regularity },
            total: (result * 10).rounded() / 10
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

// MARK: - Anteile in Prozent

enum SleepStageShares {
    /// Ganze Prozente, die zusammen genau 100 ergeben (grösster Rest zuerst
    /// aufgerundet). Leer oder nur Nullen: alles 0.
    static func percentages(_ minutes: [Double]) -> [Int] {
        let values = minutes.map { max(0, $0) }
        let total = values.reduce(0, +)
        guard total > 0 else { return values.map { _ in 0 } }
        let exact = values.map { $0 / total * 100 }
        var result = exact.map { Int($0.rounded(.down)) }
        let missing = 100 - result.reduce(0, +)
        let order = exact.indices.sorted { (exact[$0] - Double(result[$0])) > (exact[$1] - Double(result[$1])) }
        for index in order.prefix(missing) {
            result[index] += 1
        }
        return result
    }

    /// Anteil an der ganzen Nacht – so wertet der Score die Phasen.
    static func shareOfNight(_ minutes: Double?, nightMinutes: Double) -> Double? {
        guard let minutes, nightMinutes > 0 else { return nil }
        return minutes / nightMinutes * 100
    }
}
