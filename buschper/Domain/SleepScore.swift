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
    /// Wachzeit zwischen Einschlafen und Aufwachen (WASO).
    var awakeMinutes: Double
    /// Zeit „Im Bett“ laut Health (Schlafplan/Schlaf-Fokus). `nil` ohne diese Daten.
    var bedStart: Date? = nil
    var bedEnd: Date? = nil
    /// Wachphasen länger als 5 Minuten zwischen Einschlafen und Aufwachen.
    var awakenings: Int = 0

    var hasStages: Bool { deepMinutes != nil && remMinutes != nil }

    /// Einschlafdauer: von „Im Bett“ bis zum Einschlafen. `nil` ohne Bettzeit.
    var latencyMinutes: Double? {
        guard let bedStart else { return nil }
        return max(0, sleepOnset.timeIntervalSince(bedStart) / 60)
    }

    /// Zeit im Bett: mit Bettzeit von „Im Bett“ an, sonst vom Einschlafen bis zum
    /// Aufwachen.
    var timeInBedMinutes: Double {
        let start = min(bedStart ?? sleepOnset, sleepOnset)
        let end = max(bedEnd ?? wake, wake)
        return max(1, end.timeIntervalSince(start) / 60)
    }

    /// Schlafeffizienz in Prozent: Schlaf ÷ Zeit im Bett.
    var efficiencyPercent: Double {
        min(100, asleepMinutes / timeInBedMinutes * 100)
    }
}

/// Punkte und Messwerte einer Nacht (SPEC 11.2, Fassung Testrunde 14).
///
/// Optionale Teile fehlen, wenn die Daten fehlen: Einschlafdauer ohne „Im Bett“,
/// Regelmässigkeit ohne Vorgeschichte, Erholung ohne Morgen-Einschätzung.
struct SleepScoreComponents: Codable, Equatable {
    // Punkte
    var duration: Double
    var latency: Double?
    var waso: Double
    var awakenings: Double
    var efficiency: Double
    var regularity: Double?
    var recovery: Double?
    /// 0–100, fehlende Teile hochgerechnet.
    var total: Double

    // Gemessen – für die Erklärung in der App
    var asleepMinutes: Double
    var latencyMinutes: Double?
    var wasoMinutes: Double
    var awakeningCount: Int
    var efficiencyPercent: Double
    var midpointDeviationMinutes: Double?
    var rating: Int?

    var continuity: Double { (latency ?? 0) + waso + awakenings + efficiency }
}

/// Einstufung des Scores (eigene Grenzen, nicht wissenschaftlich normiert).
enum SleepGrade: String, CaseIterable {
    case good, solid, limited, poor

    /// Ab hier „solid“ – auch die Linie im Schlaf-Diagramm des Dashboards.
    static let solidFrom = 70.0

    init(score: Double) {
        switch score {
        case 85...: self = .good
        case Self.solidFrom..<85: self = .solid
        case 50..<70: self = .limited
        default: self = .poor
        }
    }

    var label: String {
        switch self {
        case .good: return "guet"
        case .solid: return "solid"
        case .limited: return "iigschränkt"
        case .poor: return "schlächt"
        }
    }
}

/// Eigener Schlafscore 0–100 (SPEC 11.2, Testrunde 14).
///
/// Gewichtet nur, was gut belegt ist und ein Wearable einigermassen zuverlässig
/// misst. Schlafphasen geben **keine** Punkte – nur zur Information.
///
/// | Block | Punkte |
/// |---|---|
/// | Dauer (AASM/SRS ≥ 7 h) | 35 |
/// | Kontinuität (NSF) | 30 |
/// | Regelmässigkeit (Schlafmitte) | 25 |
/// | Subjektive Erholung (RU-SATED) | 10 |
///
/// Wer den NSF-Wert für „gut“ erreicht, erhält die volle Punktzahl, beim Wert für
/// „schlecht“ 0, dazwischen linear. Fehlt ein Teil, werden die übrigen auf 100
/// hochgerechnet.
enum SleepScore {

    enum Weight {
        static let duration = 35.0
        static let latency = 8.0
        static let waso = 8.0
        static let awakenings = 6.0
        static let efficiency = 8.0
        static let regularity = 25.0
        static let recovery = 10.0
    }

    // MARK: - Schwellen

    /// Dauer: volle Punkte 7–9.5 h, 0 bis 5 h.
    static let durationZeroHours = 5.0
    static let durationFullHours = 7.0
    /// Sehr langer Schlaf: ab 9.5 h linear bis −5 Punkte bei 11 h.
    static let longSleepFromHours = 9.5
    static let longSleepMaxHours = 11.0
    static let longSleepMaxDeduction = 5.0
    /// Einschlafdauer: voll bis 30 min, 0 ab 45 min.
    static let latencyFullMinutes = 30.0
    static let latencyZeroMinutes = 45.0
    /// Wach nach dem Einschlafen: voll bis 20 min, 0 ab 41 min.
    static let wasoFullMinutes = 20.0
    static let wasoZeroMinutes = 41.0
    /// Aufwachphasen über 5 Minuten: voll bis 1, 0 ab 4.
    static let awakeningMinimumMinutes = 5.0
    static let awakeningsFull = 1.0
    static let awakeningsZero = 4.0
    /// Schlafeffizienz: voll ab 85 %, 0 bis 74 %.
    static let efficiencyFullPercent = 85.0
    static let efficiencyZeroPercent = 74.0
    /// Schlafmitte gegenüber dem Schnitt der letzten 7 Nächte: voll bis 30 min, 0 ab 90 min.
    static let regularityFullMinutes = 30.0
    static let regularityZeroMinutes = 90.0
    static let regularityNights = 7

    // MARK: - Berechnung

    /// Schlafmitte in Minuten seit Mittag (über Mitternacht stetig).
    static func midpointSinceNoon(onset: Date, wake: Date, calendar: Calendar = .current) -> Double {
        let middle = onset.addingTimeInterval(wake.timeIntervalSince(onset) / 2)
        return DayMath.minutesSinceNoon(middle, calendar: calendar)
    }

    static func durationPoints(asleepMinutes: Double) -> Double {
        let hours = asleepMinutes / 60
        var points = rise(hours, zeroAt: durationZeroHours, fullAt: durationFullHours) * Weight.duration
        if hours > longSleepFromHours {
            let share = min(1, (hours - longSleepFromHours) / (longSleepMaxHours - longSleepFromHours))
            points -= share * longSleepMaxDeduction
        }
        return points
    }

    /// - Parameters:
    ///   - previousMidpoints: Schlafmitten der vorangehenden Nächte in Minuten seit
    ///     Mittag (die letzten 7 zählen). Leer ohne Vorgeschichte.
    ///   - rating: Morgen-Einschätzung 1–5, `nil` solange keine da ist.
    static func score(
        night: SleepNight,
        previousMidpoints: [Double],
        rating: Int?,
        calendar: Calendar = .current
    ) -> SleepScoreComponents {
        let latencyMinutes = night.latencyMinutes
        let efficiency = night.efficiencyPercent

        var deviation: Double?
        let recent = previousMidpoints.suffix(regularityNights)
        if !recent.isEmpty {
            let mean = recent.reduce(0, +) / Double(recent.count)
            deviation = abs(midpointSinceNoon(onset: night.sleepOnset, wake: night.wake, calendar: calendar) - mean)
        }

        var components = SleepScoreComponents(
            duration: durationPoints(asleepMinutes: night.asleepMinutes),
            latency: latencyMinutes.map { fall($0, fullUntil: latencyFullMinutes, zeroFrom: latencyZeroMinutes) * Weight.latency },
            waso: fall(night.awakeMinutes, fullUntil: wasoFullMinutes, zeroFrom: wasoZeroMinutes) * Weight.waso,
            awakenings: fall(Double(night.awakenings), fullUntil: awakeningsFull, zeroFrom: awakeningsZero) * Weight.awakenings,
            efficiency: rise(efficiency, zeroAt: efficiencyZeroPercent, fullAt: efficiencyFullPercent) * Weight.efficiency,
            regularity: deviation.map { fall($0, fullUntil: regularityFullMinutes, zeroFrom: regularityZeroMinutes) * Weight.regularity },
            recovery: nil,
            total: 0,
            asleepMinutes: night.asleepMinutes,
            latencyMinutes: latencyMinutes,
            wasoMinutes: night.awakeMinutes,
            awakeningCount: night.awakenings,
            efficiencyPercent: efficiency,
            midpointDeviationMinutes: deviation,
            rating: nil
        )
        return applying(rating: rating, to: components)
    }

    /// Morgen-Einschätzung nachtragen oder ändern: Erholung und Total neu.
    static func applying(rating: Int?, to components: SleepScoreComponents) -> SleepScoreComponents {
        var result = components
        if let rating, (1...5).contains(rating) {
            result.rating = rating
            result.recovery = Double(rating - 1) / 4 * Weight.recovery
        } else {
            result.rating = nil
            result.recovery = nil
        }
        result.total = total(of: result)
        return result
    }

    /// Erreichte Punkte, auf 100 hochgerechnet über die vorhandenen Teile.
    static func total(of c: SleepScoreComponents) -> Double {
        var earned = c.duration + c.waso + c.awakenings + c.efficiency
        var possible = Weight.duration + Weight.waso + Weight.awakenings + Weight.efficiency
        for (points, weight) in [(c.latency, Weight.latency), (c.regularity, Weight.regularity), (c.recovery, Weight.recovery)] {
            guard let points else { continue }
            earned += points
            possible += weight
        }
        let value = possible > 0 ? max(0, earned) / possible * 100 : 0
        return (value * 10).rounded() / 10
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

    /// Schnitt der letzten `days` Nächte bis und mit `day` (ohne ausgeschlossene).
    static func average(of scores: [(day: Date, score: Double)], days: Int = 7, endingAt day: Date, calendar: Calendar = .current) -> Double? {
        let end = calendar.startOfDay(for: day)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return nil }
        let values = scores.filter { calendar.startOfDay(for: $0.day) >= start && calendar.startOfDay(for: $0.day) <= end }.map(\.score)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
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
