import CoreData
import Foundation

/// Ein Gewichtswert, egal ob aus Health oder von Hand.
struct WeightPoint: Equatable, Identifiable {
    enum Origin: Equatable {
        /// Von Hand in buschper erfasst – bearbeitbar.
        case manual(UUID)
        /// Aus einer fremden Quelle – nur lesbar, aber ignorierbar.
        case health(UUID, source: String)
    }

    var date: Date
    var kg: Double
    var origin: Origin

    var id: String {
        switch origin {
        case .manual(let id): return "m-\(id.uuidString)"
        case .health(let id, _): return "h-\(id.uuidString)"
        }
    }

    var isManual: Bool {
        if case .manual = origin { return true }
        return false
    }
}

/// Ein Training des Tages, egal ob manuell oder aus Health.
struct DayWorkout: Equatable, Identifiable {
    var id: String
    var start: Date
    var end: Date
    var sport: SportType
    var kcal: Double?
    var intensity: WorkoutIntensity?
    var averageHeartRate: Double?
    /// Kennung des manuellen Eintrags, `nil` bei fremden Trainings.
    var manualId: UUID?
    var sourceName: String?

    var durationMinutes: Double { end.timeIntervalSince(start) / 60 }
}

/// Alle Ziele eines Tages (SPEC 4).
struct DailyTargets: Equatable {
    var day: Date
    var weightKg: Double
    /// `true`, wenn kein Gewicht der letzten 30 Tage bekannt war.
    var weightIsFallback: Bool
    var budget: EnergyCalculator.Budget
    var macros: MacroTargets
    var fluidGoalMl: Double
    var trainingMinutes: Double
}

/// Führt Profil, Core Data und Apple Health zu den Zahlen eines Tages zusammen.
@MainActor
final class DayDataService {
    let store: DataStore
    let health: HealthDataProviding
    private let calendar: Calendar

    init(store: DataStore, health: HealthDataProviding, calendar: Calendar = .current) {
        self.store = store
        self.health = health
        self.calendar = calendar
    }

    // MARK: - Gewicht

    /// Gewichte aus Health (ohne ignorierte) und von Hand, zeitlich sortiert.
    func weights(from start: Date, to end: Date) async -> [WeightPoint] {
        let ignored = store.ignoredSampleIDs(kind: .weight)
        let foreign = await health.foreignWeights(from: start, to: end)
            .filter { !ignored.contains($0.id.uuidString) }
            .map { WeightPoint(date: $0.date, kg: $0.kg, origin: .health($0.id, source: $0.sourceName)) }

        let manual = store.fetch(
            WeightEntry.self,
            predicate: DataStore.rangePredicate("timestamp", from: start, to: end)
        ).compactMap { entry -> WeightPoint? in
            guard let id = entry.id, let date = entry.timestamp, entry.kg > 0 else { return nil }
            return WeightPoint(date: date, kg: entry.kg, origin: .manual(id))
        }

        return (foreign + manual).sorted { $0.date < $1.date }
    }

    func dailyWeights(from start: Date, to end: Date) async -> [DailyWeight] {
        let points = await weights(from: start, to: end)
        return WeightMath.daily(points.map { WeightSample(date: $0.date, kg: $0.kg) }, calendar: calendar)
    }

    /// Gewicht für die Bedarfsberechnung: 7-Tage-Schnitt, sonst der letzte Wert der
    /// letzten 30 Tage, sonst der im Profil hinterlegte Rückfallwert (Q12).
    func referenceWeight(for day: Date) async -> (kg: Double, isFallback: Bool) {
        let end = DayMath.nextDay(of: day, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let daily = await dailyWeights(from: start, to: end)
        if let average = WeightMath.average(daily, days: 7, endingAt: day, calendar: calendar) {
            return (average, false)
        }
        if let latest = WeightMath.latest(daily) {
            return (latest.kg, false)
        }
        let fallback = store.profile().fallbackWeightKg
        return (fallback > 0 ? fallback : 75, true)
    }

    // MARK: - Trainings

    /// Manuelle Trainings aus buschper und fremde aus Health. Eigene Health-Trainings
    /// werden übersprungen – sie sind die manuellen, schon erfasst.
    func workouts(on day: Date) async -> [DayWorkout] {
        let start = calendar.startOfDay(for: day)
        let end = DayMath.nextDay(of: start, calendar: calendar)

        let manual = store.fetch(
            WorkoutEntry.self,
            predicate: DataStore.rangePredicate("start", from: start, to: end)
        ).compactMap { entry -> DayWorkout? in
            guard let id = entry.id, let begin = entry.start, let finish = entry.end else { return nil }
            return DayWorkout(
                id: "m-\(id.uuidString)", start: begin, end: finish, sport: entry.sportType,
                kcal: entry.kcal, intensity: entry.intensity, averageHeartRate: nil,
                manualId: id, sourceName: nil
            )
        }

        let foreign = await health.workouts(from: start, to: end)
            .filter { !$0.isOwn }
            .map { workout in
                DayWorkout(
                    id: "h-\(workout.id.uuidString)", start: workout.start, end: workout.end,
                    sport: workout.sport, kcal: workout.kcal, intensity: nil,
                    averageHeartRate: workout.averageHeartRate, manualId: nil,
                    sourceName: workout.sourceName
                )
            }

        return (manual + foreign).sorted { $0.start < $1.start }
    }

    // MARK: - Ziele

    func targets(for day: Date, now: Date = Date()) async -> DailyTargets {
        let profile = store.profile()
        let weight = await referenceWeight(for: day)
        let bmr = profile.basalMetabolicRate(weightKg: weight.kg, on: day)
        let active = await health.activeEnergy(on: day)

        let budget = EnergyCalculator.budget(
            bmr: bmr,
            measuredActiveKcal: active,
            activityProfile: profile.activityProfile,
            goalOffset: profile.goalOffset,
            sex: profile.sex,
            dayStart: day,
            now: now,
            calendar: calendar
        )
        let macros = MacroTargets.from(kcalBudget: budget.total, split: profile.macroSplit, fiberMinG: profile.fiberMinG)
        let trainingMinutes = await workouts(on: day).reduce(0) { $0 + $1.durationMinutes }
        let fluid = FluidCalculator.goalMl(
            weightKg: weight.kg,
            trainingMinutes: trainingMinutes,
            overrideMl: profile.waterGoalOverride
        )

        return DailyTargets(
            day: calendar.startOfDay(for: day),
            weightKg: weight.kg,
            weightIsFallback: weight.isFallback,
            budget: budget,
            macros: macros,
            fluidGoalMl: fluid,
            trainingMinutes: trainingMinutes
        )
    }
}
