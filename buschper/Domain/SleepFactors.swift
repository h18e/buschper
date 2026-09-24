import Foundation

/// Mögliche Ursachen einer schlechten Nacht, geprüft am Vortag (SPEC 12.3).
enum SleepFactor: String, Codable, CaseIterable, Identifiable {
    case alcohol
    case lateCaffeine
    case lateMeal
    case heavyDinner
    case calorieImbalance
    case lowFluid
    case lowActivity
    case lateWorkout

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alcohol: return "Alkohol"
        case .lateCaffeine: return "Koffein spät"
        case .lateMeal: return "Spät gässe"
        case .heavyDinner: return "Schwärs Znacht"
        case .calorieImbalance: return "Kalorie-Bilanz"
        case .lowFluid: return "Z'weni trunke"
        case .lowActivity: return "Z'weni Bewegig"
        case .lateWorkout: return "Spats Training"
        }
    }

    var symbolName: String {
        switch self {
        case .alcohol: return "wineglass.fill"
        case .lateCaffeine: return "cup.and.saucer.fill"
        case .lateMeal: return "clock.badge.exclamationmark.fill"
        case .heavyDinner: return "fork.knife"
        case .calorieImbalance: return "scalemass.fill"
        case .lowFluid: return "drop.triangle.fill"
        case .lowActivity: return "figure.stand"
        case .lateWorkout: return "figure.run"
        }
    }
}

/// Schwellen der Faktoren. Alle einstellbar, Vorgaben aus SPEC 12.3.
struct FactorThresholds: Codable, Equatable {
    /// Alkohol über diesem Wert in g ist auffällig (Vorgabe: jeder Alkohol).
    var alcoholGrams: Double = 0
    /// Koffein ab dieser Minute des Tages (14:00).
    var caffeineCutoffMinute: Double = 14 * 60
    /// Letzte Mahlzeit ab dieser Minute des Tages (20:00).
    var lateMealMinute: Double = 20 * 60
    /// Znacht über diesem Anteil der Tages-kcal.
    var dinnerShareMax: Double = 0.35
    /// Fettanteil (an den kcal) des Znachts über diesem Wert.
    var dinnerFatShareMax: Double = 0.40
    /// Abweichung vom Budget, nach oben oder unten.
    var calorieDeviationMax: Double = 0.20
    /// Flüssigkeit unter diesem Anteil des Ziels.
    var fluidMinShare: Double = 0.70
    /// Schritte unter diesem Anteil des 30-Tage-Schnitts.
    var stepsMinShare: Double = 0.50
    /// Intensives Training, das weniger als so viele Stunden vor dem Einschlafen endet.
    var workoutGapHours: Double = 2

    static let standard = FactorThresholds()
}

/// Ein Training, wie es für die Analyse zählt.
struct WorkoutSummary: Codable, Equatable {
    var end: Date
    var isIntense: Bool
}

/// Kennzahlen eines Tages, die zu einer Nacht gespeichert werden (SPEC 12.2).
///
/// Jede Kennzahl ist optional: Was nicht erfasst wurde, löst auch keinen Faktor aus.
struct DayMetrics: Codable, Equatable {
    var kcalEaten: Double?
    var kcalBudget: Double?
    var carbsG: Double?
    var proteinG: Double?
    var fatG: Double?
    var dinnerKcal: Double?
    var dinnerFatG: Double?
    /// Minuten seit Tagesbeginn, siehe `DayMath.minutes(of:sinceStartOf:)`.
    var lastMealMinute: Double?
    var alcoholG: Double?
    var caffeineMg: Double?
    var lastCaffeineMinute: Double?
    var fluidMl: Double?
    var fluidGoalMl: Double?
    var steps: Double?
    var stepsAverage30: Double?
    var workouts: [WorkoutSummary] = []
    var sleepOnset: Date?

    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func decode(_ json: String?) -> DayMetrics? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DayMetrics.self, from: data)
    }
}

enum FactorEvaluator {
    static func factors(for metrics: DayMetrics, thresholds: FactorThresholds) -> Set<SleepFactor> {
        var result = Set<SleepFactor>()

        if let alcohol = metrics.alcoholG, alcohol > thresholds.alcoholGrams, alcohol > 0 {
            result.insert(.alcohol)
        }

        if let minute = metrics.lastCaffeineMinute, (metrics.caffeineMg ?? 0) > 0,
           minute >= thresholds.caffeineCutoffMinute {
            result.insert(.lateCaffeine)
        }

        if let minute = metrics.lastMealMinute, minute >= thresholds.lateMealMinute {
            result.insert(.lateMeal)
        }

        if let dinner = metrics.dinnerKcal, dinner > 0 {
            let dayTotal = metrics.kcalEaten ?? 0
            let tooLarge = dayTotal > 0 && dinner / dayTotal > thresholds.dinnerShareMax
            let fatKcal = (metrics.dinnerFatG ?? 0) * Nutrients.EnergyFactor.fat
            let tooFat = fatKcal / dinner > thresholds.dinnerFatShareMax
            if tooLarge || tooFat {
                result.insert(.heavyDinner)
            }
        }

        if let eaten = metrics.kcalEaten, let budget = metrics.kcalBudget, budget > 0, eaten > 0,
           abs(eaten - budget) / budget > thresholds.calorieDeviationMax {
            result.insert(.calorieImbalance)
        }

        if let fluid = metrics.fluidMl, let goal = metrics.fluidGoalMl, goal > 0,
           fluid / goal < thresholds.fluidMinShare {
            result.insert(.lowFluid)
        }

        if let steps = metrics.steps, let average = metrics.stepsAverage30, average > 0,
           steps / average < thresholds.stepsMinShare {
            result.insert(.lowActivity)
        }

        if let onset = metrics.sleepOnset {
            let gap = thresholds.workoutGapHours * 3600
            let late = metrics.workouts.contains { workout in
                workout.isIntense && workout.end <= onset && onset.timeIntervalSince(workout.end) < gap
            }
            if late {
                result.insert(.lateWorkout)
            }
        }

        return result
    }
}

// MARK: - Kennzahlen aus einzelnen Einträgen

/// Ein Ess- oder Trinkeintrag, reduziert auf das, was die Analyse braucht.
struct IntakeEvent: Equatable {
    var time: Date
    var category: MealCategory?
    var nutrients: Nutrients
    /// Flüssigkeit in ml, die zum Ziel zählt (0 bei Essen und Alkohol).
    var fluidMl: Double = 0
    /// `true` für Essen, `false` für Getränke. Nur Essen zählt als „Mahlzeit“.
    var isFood: Bool
}

enum DayMetricsBuilder {
    /// Ab dieser Minute zählt Gegessenes zum Znacht, auch wenn es als Snack erfasst ist.
    static let dinnerStartMinute = 17 * 60 + 30.0

    /// Baut die Kennzahlen des Vortags. `events` sind alle Einträge von Tagesbeginn
    /// bis zum Einschlafen – also inklusive allem nach Mitternacht.
    static func build(
        day: Date,
        events: [IntakeEvent],
        kcalBudget: Double?,
        fluidGoalMl: Double?,
        steps: Double?,
        stepsAverage30: Double?,
        workouts: [WorkoutSummary],
        sleepOnset: Date?,
        calendar: Calendar = .current
    ) -> DayMetrics {
        let relevant = events.filter { event in
            guard let onset = sleepOnset else { return true }
            return event.time <= onset
        }

        let total = NutrientSum(relevant.map(\.nutrients)).values

        let dinner = relevant.filter { event in
            guard event.isFood else { return false }
            if event.category?.isDinner == true { return true }
            return DayMath.minutes(of: event.time, sinceStartOf: day, calendar: calendar) >= dinnerStartMinute
        }
        let dinnerSum = NutrientSum(dinner.map(\.nutrients)).values

        let foods = relevant.filter(\.isFood)
        let lastMeal = foods.map { DayMath.minutes(of: $0.time, sinceStartOf: day, calendar: calendar) }.max()

        let caffeinated = relevant.filter { ($0.nutrients.caffeine ?? 0) > 0 }
        let lastCaffeine = caffeinated.map { DayMath.minutes(of: $0.time, sinceStartOf: day, calendar: calendar) }.max()

        let fluid = relevant.reduce(0) { $0 + $1.fluidMl }

        return DayMetrics(
            kcalEaten: relevant.isEmpty ? nil : (total.kcal ?? 0),
            kcalBudget: kcalBudget,
            carbsG: total.carbs,
            proteinG: total.protein,
            fatG: total.fat,
            dinnerKcal: dinner.isEmpty ? nil : (dinnerSum.kcal ?? 0),
            dinnerFatG: dinnerSum.fat,
            lastMealMinute: lastMeal,
            alcoholG: total.alcohol,
            caffeineMg: total.caffeine,
            lastCaffeineMinute: lastCaffeine,
            fluidMl: relevant.isEmpty ? nil : fluid,
            fluidGoalMl: fluidGoalMl,
            steps: steps,
            stepsAverage30: stepsAverage30,
            workouts: workouts,
            sleepOnset: sleepOnset
        )
    }
}
