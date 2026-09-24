import CoreData
import Foundation

extension Profile {
    var sex: Sex {
        get { Sex(rawValue: sexRaw ?? "") ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var goal: WeightGoal {
        get { WeightGoal(rawValue: goalRaw ?? "") ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    var activityProfile: ActivityProfile {
        get { ActivityProfile(rawValue: activityProfileRaw ?? "") ?? .light }
        set { activityProfileRaw = newValue.rawValue }
    }

    /// Abschlag des aktuell gewählten Ziels.
    var goalOffset: Double {
        offset(for: goal)
    }

    func offset(for goal: WeightGoal) -> Double {
        switch goal {
        case .lose: return offsetLose
        case .maintain: return offsetMaintain
        case .gain: return offsetGain
        }
    }

    func setOffset(_ value: Double, for goal: WeightGoal) {
        switch goal {
        case .lose: offsetLose = value
        case .maintain: offsetMaintain = value
        case .gain: offsetGain = value
        }
    }

    var macroSplit: MacroSplit {
        get { MacroSplit(carbsPercent: carbsPercent, proteinPercent: proteinPercent, fatPercent: fatPercent) }
        set {
            carbsPercent = newValue.carbsPercent
            proteinPercent = newValue.proteinPercent
            fatPercent = newValue.fatPercent
        }
    }

    var dashboardLayout: DashboardLayout {
        get { DashboardLayout.decode(dashboardLayoutJSON) }
        set { dashboardLayoutJSON = newValue.jsonString }
    }

    var factorThresholds: FactorThresholds {
        get { JSONField.decode(factorThresholdsJSON) ?? .standard }
        set { factorThresholdsJSON = JSONField.encode(newValue) }
    }

    var badNightRules: BadNightRules {
        get { JSONField.decode(badNightRulesJSON) ?? .standard }
        set { badNightRulesJSON = JSONField.encode(newValue) }
    }

    /// Von Hand gesetztes Flüssigkeitsziel, `nil` wenn die Formel gilt.
    var waterGoalOverride: Double? {
        get { waterGoalOverrideMl > 0 ? waterGoalOverrideMl : nil }
        set { waterGoalOverrideMl = max(0, newValue ?? 0) }
    }

    var targetWeight: Double? {
        get { targetWeightKg > 0 ? targetWeightKg : nil }
        set { targetWeightKg = max(0, newValue ?? 0) }
    }

    var sleepGoal: Double { Double(max(60, sleepGoalMinutes)) }

    func age(on date: Date = Date()) -> Int {
        guard let birthDate else { return 40 }
        return EnergyCalculator.age(birthDate: birthDate, on: date)
    }

    func basalMetabolicRate(weightKg: Double, on date: Date = Date()) -> Double {
        EnergyCalculator.basalMetabolicRate(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age(on: date))
    }
}

/// Kleine Hilfe für Einstellungen, die als JSON-Text im Modell liegen.
enum JSONField {
    static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode<T: Decodable>(_ json: String?) -> T? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
