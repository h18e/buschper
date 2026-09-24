import Foundation

/// Aktivitätsgrad nach Schritten (SPEC 10.1).
enum ActivityLevel: Int, CaseIterable, Comparable {
    case low
    case light
    case moderate
    case active

    init(steps: Double) {
        switch steps {
        case ..<5_000: self = .low
        case ..<7_500: self = .light
        case ..<10_000: self = .moderate
        default: self = .active
        }
    }

    var label: String {
        switch self {
        case .low: return "Tief"
        case .light: return "Liecht"
        case .moderate: return "Moderat"
        case .active: return "Aktiv"
        }
    }

    static func < (lhs: ActivityLevel, rhs: ActivityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum WorkoutIntensity: String, Codable, CaseIterable, Identifiable {
    case light
    case moderate
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Liecht"
        case .moderate: return "Mittu"
        case .hard: return "Hert"
        }
    }

    /// Zählt für die Schlafanalyse als „intensiv“.
    var isIntense: Bool { self == .hard }
}

/// Sportarten für manuelle Trainings, mit MET-Werten je Intensität.
///
/// MET-Werte nach dem Compendium of Physical Activities (Ainsworth et al.),
/// auf typische Werte gerundet.
enum SportType: String, Codable, CaseIterable, Identifiable {
    case walking
    case running
    case cycling
    case hiking
    case swimming
    case strength
    case yoga
    case skiing
    case crossCountrySkiing
    case dancing
    case teamSport
    case racketSport
    case rowing
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walking: return "Loufe"
        case .running: return "Jogge"
        case .cycling: return "Velo"
        case .hiking: return "Wandere"
        case .swimming: return "Schwümme"
        case .strength: return "Chraft"
        case .yoga: return "Yoga"
        case .skiing: return "Ski"
        case .crossCountrySkiing: return "Langlouf"
        case .dancing: return "Tanze"
        case .teamSport: return "Mannschaftssport"
        case .racketSport: return "Tennis & Co."
        case .rowing: return "Rudere"
        case .other: return "Eigets"
        }
    }

    var symbolName: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        case .swimming: return "figure.pool.swim"
        case .strength: return "figure.strengthtraining.traditional"
        case .yoga: return "figure.yoga"
        case .skiing: return "figure.skiing.downhill"
        case .crossCountrySkiing: return "figure.skiing.crosscountry"
        case .dancing: return "figure.dance"
        case .teamSport: return "figure.soccer"
        case .racketSport: return "figure.tennis"
        case .rowing: return "figure.rower"
        case .other: return "figure.mixed.cardio"
        }
    }

    func met(_ intensity: WorkoutIntensity) -> Double {
        let values: (Double, Double, Double)
        switch self {
        case .walking: values = (2.8, 3.5, 5.0)
        case .running: values = (7.0, 9.8, 11.5)
        case .cycling: values = (4.0, 6.8, 10.0)
        case .hiking: values = (5.3, 6.0, 7.8)
        case .swimming: values = (5.8, 8.3, 9.8)
        case .strength: values = (3.5, 5.0, 6.0)
        case .yoga: values = (2.5, 3.0, 4.0)
        case .skiing: values = (4.3, 5.3, 8.0)
        case .crossCountrySkiing: values = (6.8, 9.0, 12.5)
        case .dancing: values = (4.5, 5.5, 7.8)
        case .teamSport: values = (5.0, 7.0, 10.0)
        case .racketSport: values = (5.0, 7.3, 8.0)
        case .rowing: values = (4.8, 7.0, 8.5)
        case .other: values = (3.5, 5.0, 7.0)
        }
        switch intensity {
        case .light: return values.0
        case .moderate: return values.1
        case .hard: return values.2
        }
    }
}

enum WorkoutEstimator {
    /// `kcal = MET × kg × Stunden`
    static func kcal(sport: SportType, intensity: WorkoutIntensity, weightKg: Double, durationMinutes: Double) -> Double {
        let raw = sport.met(intensity) * max(0, weightKg) * max(0, durationMinutes) / 60
        return raw.rounded()
    }
}
