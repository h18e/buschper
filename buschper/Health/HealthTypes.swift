import Foundation
import HealthKit

/// Welche Health-Typen buschper liest und schreibt (SPEC 8).
enum HealthTypes {
    /// Unter diesem Metadaten-Schlüssel steht an jedem Wert, den buschper schreibt,
    /// die Kennung des eigenen Eintrags. Damit lassen sich Werte beim Ändern und
    /// Löschen wiederfinden, ohne Health-Kennungen speichern zu müssen.
    static let localIdKey = "ch.hebera.buschper.localId"

    static let activeEnergy = HKQuantityType(.activeEnergyBurned)
    static let steps = HKQuantityType(.stepCount)
    static let exerciseTime = HKQuantityType(.appleExerciseTime)
    static let bodyMass = HKQuantityType(.bodyMass)
    static let height = HKQuantityType(.height)
    static let heartRate = HKQuantityType(.heartRate)
    static let water = HKQuantityType(.dietaryWater)
    static let sleep = HKCategoryType(.sleepAnalysis)
    static let food = HKCorrelationType(.food)
    static let workout = HKObjectType.workoutType()

    /// Die Nährwerte, die als Teil einer Mahlzeit geschrieben werden, mit ihrer
    /// Umrechnung aus buschpers Werten.
    struct NutrientMapping {
        let field: Nutrients.Field
        let type: HKQuantityType
        let unit: HKUnit
        /// buschper-Wert → Health-Wert (Salz → Natrium).
        let convert: (Double) -> Double
    }

    static let nutrientMappings: [NutrientMapping] = [
        NutrientMapping(field: .kcal, type: HKQuantityType(.dietaryEnergyConsumed), unit: .kilocalorie()) { $0 },
        NutrientMapping(field: .carbs, type: HKQuantityType(.dietaryCarbohydrates), unit: .gram()) { $0 },
        NutrientMapping(field: .sugar, type: HKQuantityType(.dietarySugar), unit: .gram()) { $0 },
        NutrientMapping(field: .fat, type: HKQuantityType(.dietaryFatTotal), unit: .gram()) { $0 },
        NutrientMapping(field: .saturatedFat, type: HKQuantityType(.dietaryFatSaturated), unit: .gram()) { $0 },
        NutrientMapping(field: .protein, type: HKQuantityType(.dietaryProtein), unit: .gram()) { $0 },
        NutrientMapping(field: .fiber, type: HKQuantityType(.dietaryFiber), unit: .gram()) { $0 },
        // Salz = Natrium × 2.5
        NutrientMapping(field: .salt, type: HKQuantityType(.dietarySodium), unit: .gramUnit(with: .milli)) { $0 / 2.5 * 1000 },
        NutrientMapping(field: .caffeine, type: HKQuantityType(.dietaryCaffeine), unit: .gramUnit(with: .milli)) { $0 }
    ]

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            activeEnergy, steps, exerciseTime, bodyMass, height, heartRate, sleep, workout,
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex)
        ]
        // Die eigenen geschriebenen Typen auch lesen, damit Löschen funktioniert.
        types.insert(water)
        for mapping in nutrientMappings {
            types.insert(mapping.type)
        }
        return types
    }

    /// Ohne `food`: Für Korrelationstypen darf man keine Berechtigung anfragen –
    /// HealthKit bricht sonst mit einer Ausnahme ab. Die Berechtigung für die
    /// enthaltenen Nährwerte genügt, um Mahlzeiten zu schreiben.
    static var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [bodyMass, water, workout, activeEnergy]
        for mapping in nutrientMappings {
            types.insert(mapping.type)
        }
        return types
    }

    /// Typen, in denen buschper eigene Werte löschen muss. Die Mahlzeit-Korrelation
    /// selbst wird separat behandelt, siehe `HealthKitService.deleteOwnSamples`.
    static var ownWrittenTypes: [HKSampleType] {
        var types: [HKSampleType] = [water, bodyMass, workout, activeEnergy]
        types.append(contentsOf: nutrientMappings.map { $0.type as HKSampleType })
        return types
    }
}

extension SportType {
    /// Zuordnung zu Apples Trainingsarten.
    var healthActivityType: HKWorkoutActivityType {
        switch self {
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .hiking: return .hiking
        case .swimming: return .swimming
        case .strength: return .traditionalStrengthTraining
        case .yoga: return .yoga
        case .skiing: return .downhillSkiing
        case .crossCountrySkiing: return .crossCountrySkiing
        case .dancing: return .socialDance
        case .teamSport: return .soccer
        case .racketSport: return .tennis
        case .rowing: return .rowing
        case .other: return .other
        }
    }

    /// Umgekehrt, für die Anzeige fremder Trainings.
    init(healthActivityType type: HKWorkoutActivityType) {
        switch type {
        case .walking: self = .walking
        case .running: self = .running
        case .cycling: self = .cycling
        case .hiking: self = .hiking
        case .swimming: self = .swimming
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: self = .strength
        case .yoga, .pilates, .mindAndBody: self = .yoga
        case .downhillSkiing, .snowboarding: self = .skiing
        case .crossCountrySkiing: self = .crossCountrySkiing
        case .socialDance, .cardioDance: self = .dancing
        case .soccer, .basketball, .handball, .volleyball, .hockey: self = .teamSport
        case .tennis, .badminton, .squash, .tableTennis, .pickleball: self = .racketSport
        case .rowing: self = .rowing
        default: self = .other
        }
    }
}
