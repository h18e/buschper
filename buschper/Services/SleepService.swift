import CoreData
import Foundation
import os

/// Wertet Nächte aus und speichert sie als `NightRecord` (SPEC 11, 12).
///
/// Für **jede** Nacht werden Score, Einstufung und die Kennzahlen des Vortags
/// gespeichert – nicht nur für schlechte, sonst gäbe es nichts zum Vergleichen.
/// Was du selbst eingibst (Sterne, Notiz, Marken, Ausschluss), bleibt bei jeder
/// Neuberechnung erhalten.
@MainActor
final class SleepService {
    private let store: DataStore
    private let health: HealthDataProviding
    private let dayData: DayDataService
    private let calendar: Calendar
    private var isRunning = false
    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "Sleep")

    init(store: DataStore, health: HealthDataProviding, dayData: DayDataService, calendar: Calendar = .current) {
        self.store = store
        self.health = health
        self.dayData = dayData
        self.calendar = calendar
    }

    func record(for nightDay: Date) -> NightRecord? {
        let day = calendar.startOfDay(for: nightDay)
        return store.fetch(
            NightRecord.self,
            predicate: DataStore.rangePredicate("nightDate", from: day, to: DayMath.nextDay(of: day, calendar: calendar)),
            limit: 1
        ).first
    }

    /// Die letzten `days` Nächte neu auswerten, älteste zuerst – so stehen Median
    /// der Einschlafzeit und 30-Tage-Schnitt für die jüngeren schon bereit.
    func refresh(days: Int = 14) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let today = calendar.startOfDay(for: Date())
        let profile = store.profile()
        let stepsStart = calendar.date(byAdding: .day, value: -(days + 31), to: today) ?? today
        let stepHistory = await health.dailySteps(from: stepsStart, to: today)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let nightDay = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            await evaluate(nightDay: nightDay, profile: profile, stepHistory: stepHistory)
        }
        store.save()
    }

    private func evaluate(nightDay: Date, profile: Profile, stepHistory: [Date: Double]) async {
        let window = SleepNightBuilder.window(for: nightDay, calendar: calendar)
        let samples = await health.sleepSamples(from: window.start, to: window.end)
        guard let night = SleepNightBuilder.build(from: samples) else { return }

        // Vorgeschichte aus den gespeicherten Nächten davor.
        let previous = store.nights(
            from: calendar.date(byAdding: .day, value: -30, to: nightDay) ?? nightDay,
            to: calendar.startOfDay(for: nightDay)
        )
        let recentOnsets = previous.suffix(14).compactMap(\.sleepOnset).map { DayMath.minutesSinceNoon($0, calendar: calendar) }
        let median = DayMath.median(recentOnsets)
        let average30 = DayMath.average(previous.map(\.score))

        let components = SleepScore.score(
            night: night,
            sleepGoalMinutes: profile.sleepGoal,
            medianOnsetSinceNoon: median,
            calendar: calendar
        )

        let record = record(for: nightDay) ?? {
            let record = NightRecord(context: store.context)
            record.id = UUID()
            record.nightDate = calendar.startOfDay(for: nightDay)
            return record
        }()

        record.score = components.total
        record.components = components
        record.asleepMinutes = night.asleepMinutes
        record.deepMinutes = night.deepMinutes ?? 0
        record.remMinutes = night.remMinutes ?? 0
        record.coreMinutes = night.coreMinutes ?? 0
        record.awakeMinutes = night.awakeMinutes
        record.hasStages = night.hasStages
        record.sleepOnset = night.sleepOnset
        record.wakeTime = night.wake

        let metrics = await dayMetrics(forNightOf: nightDay, onset: night.sleepOnset, profile: profile, stepHistory: stepHistory)
        record.dayMetrics = metrics
        record.factors = FactorEvaluator.factors(for: metrics, thresholds: profile.factorThresholds)

        classify(record, average30: average30, rules: profile.badNightRules)
        record.computedAt = Date()
    }

    /// Schlecht oder nicht – auch nach einer neuen Morgen-Einschätzung aufrufen.
    func classify(_ record: NightRecord, average30: Double? = nil, rules: BadNightRules? = nil) {
        let rules = rules ?? store.profile().badNightRules
        let average = average30 ?? { () -> Double? in
            guard let day = record.nightDate else { return nil }
            let previous = store.nights(from: calendar.date(byAdding: .day, value: -30, to: day) ?? day, to: day)
            return DayMath.average(previous.map(\.score))
        }()
        let reasons = NightClassifier.reasons(score: record.score, average30: average, rating: record.ratingValue, rules: rules)
        record.badReasons = reasons
        record.isBad = !reasons.isEmpty
    }

    // MARK: - Vortag

    private func dayMetrics(forNightOf nightDay: Date, onset: Date, profile: Profile, stepHistory: [Date: Double]) async -> DayMetrics {
        let day = DayMath.previousDay(of: nightDay, calendar: calendar)
        let start = calendar.startOfDay(for: day)

        var events: [IntakeEvent] = []
        for meal in store.meals(from: start, to: onset) {
            guard let time = meal.timestamp else { continue }
            events.append(IntakeEvent(time: time, category: meal.category, nutrients: meal.nutrientSum.values, isFood: true))
        }
        for drink in store.drinks(from: start, to: onset) {
            guard let time = drink.timestamp else { continue }
            events.append(IntakeEvent(time: time, category: nil, nutrients: drink.total, fluidMl: drink.fluidMl, isFood: false))
        }

        let targets = await dayData.targets(for: day, now: Date())

        let previousSteps = (1...30).compactMap { offset -> Double? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return stepHistory[date]
        }.filter { $0 > 0 }

        let maxHeartRate = 220 - Double(profile.age(on: day))
        let workouts = await dayData.workouts(on: day).map { workout -> WorkoutSummary in
            let intenseByHeart = (workout.averageHeartRate ?? 0) >= 0.7 * maxHeartRate
            let intenseByEnergy = workout.durationMinutes > 0 && (workout.kcal ?? 0) / workout.durationMinutes >= 10
            let intense = workout.intensity?.isIntense ?? (intenseByHeart || intenseByEnergy)
            return WorkoutSummary(end: workout.end, isIntense: intense)
        }

        return DayMetricsBuilder.build(
            day: day,
            events: events,
            kcalBudget: targets.budget.total,
            fluidGoalMl: targets.fluidGoalMl,
            steps: stepHistory[start],
            stepsAverage30: DayMath.average(previousSteps),
            workouts: workouts,
            sleepOnset: onset,
            calendar: calendar
        )
    }
}
