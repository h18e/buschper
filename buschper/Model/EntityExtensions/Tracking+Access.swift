import CoreData
import Foundation

extension WorkoutEntry {
    var sportType: SportType {
        get { SportType(rawValue: sportTypeRaw ?? "") ?? .other }
        set { sportTypeRaw = newValue.rawValue }
    }

    var intensity: WorkoutIntensity {
        get { WorkoutIntensity(rawValue: intensityRaw ?? "") ?? .moderate }
        set { intensityRaw = newValue.rawValue }
    }

    var end: Date? {
        start.map { $0.addingTimeInterval(durationMinutes * 60) }
    }
}

/// Schnellmarken für die Notiz zu einer Nacht (SPEC 12.2).
enum NightTag: String, Codable, CaseIterable, Identifiable {
    case stress
    case sick
    case travel
    case noise
    case child

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stress: return "Stress"
        case .sick: return "Chrank"
        case .travel: return "Reis"
        case .noise: return "Lärm"
        case .child: return "Chind wach"
        }
    }
}

extension NightRecord {
    var components: SleepScoreComponents? {
        get { JSONField.decode(componentsJSON) }
        set { componentsJSON = newValue.map { JSONField.encode($0) } ?? "" }
    }

    var factors: Set<SleepFactor> {
        get { Set(JSONField.decode(factorsJSON) as [SleepFactor]? ?? []) }
        set { factorsJSON = JSONField.encode(newValue.sorted { $0.rawValue < $1.rawValue }) }
    }

    var badReasons: [BadNightReason] {
        get { JSONField.decode(badReasonsJSON) ?? [] }
        set { badReasonsJSON = JSONField.encode(newValue) }
    }

    var dayMetrics: DayMetrics? {
        get { DayMetrics.decode(dayMetricsJSON) }
        set { dayMetricsJSON = newValue?.jsonString ?? "" }
    }

    var tags: Set<NightTag> {
        get { Set(JSONField.decode(tagsJSON) as [NightTag]? ?? []) }
        set { tagsJSON = JSONField.encode(newValue.sorted { $0.rawValue < $1.rawValue }) }
    }

    /// Morgen-Einschätzung 1–5, `nil` wenn keine abgegeben wurde.
    var ratingValue: Int? {
        get { rating > 0 ? Int(rating) : nil }
        set { rating = Int16(min(5, max(0, newValue ?? 0))) }
    }

    var sample: NightSample {
        NightSample(score: score, isBad: isBad, factors: factors, excluded: excluded)
    }
}

/// Welche Art von Health-Wert ignoriert oder verknüpft wird.
enum HealthSampleKind: String, Codable {
    case weight
    case workout
    case meal
    case water
}
