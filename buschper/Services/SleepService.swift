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
    /// Wie viele Nächte in dieser Sitzung schon ausgewertet wurden.
    private var evaluatedDays = 0
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
    /// Wertet so viele Nächte aus, wie ein Graph braucht – aber nur einmal pro Sitzung.
    func ensureEvaluated(days: Int) async {
        guard days > evaluatedDays else { return }
        await refresh(days: days)
    }

    func refresh(days: Int = 14) async {
        guard !isRunning else { return }
        isRunning = true
        defer {
            isRunning = false
            evaluatedDays = max(evaluatedDays, days)
        }

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
        let previousMidpoints = previous.compactMap { record -> Double? in
            guard let onset = record.sleepOnset, let wake = record.wakeTime else { return nil }
            return SleepScore.midpointSinceNoon(onset: onset, wake: wake, calendar: calendar)
        }
        let average30 = DayMath.average(previous.map(\.score))
        let existing = record(for: nightDay)

        let components = SleepScore.score(
            night: night,
            previousMidpoints: previousMidpoints,
            rating: existing?.ratingValue,
            calendar: calendar
        )

        let nightRecord = existing ?? {
            let created = NightRecord(context: store.context)
            created.id = UUID()
            created.nightDate = calendar.startOfDay(for: nightDay)
            return created
        }()

        nightRecord.score = components.total
        nightRecord.components = components
        nightRecord.asleepMinutes = night.asleepMinutes
        nightRecord.deepMinutes = night.deepMinutes ?? 0
        nightRecord.remMinutes = night.remMinutes ?? 0
        nightRecord.coreMinutes = night.coreMinutes ?? 0
        nightRecord.awakeMinutes = night.awakeMinutes
        nightRecord.hasStages = night.hasStages
        nightRecord.sleepOnset = night.sleepOnset
        nightRecord.wakeTime = night.wake

        let metrics = await dayMetrics(forNightOf: nightDay, onset: night.sleepOnset, profile: profile, stepHistory: stepHistory)
        nightRecord.dayMetrics = metrics
        nightRecord.factors = FactorEvaluator.factors(for: metrics, thresholds: profile.factorThresholds)

        classify(nightRecord, average30: average30, rules: profile.badNightRules)
        nightRecord.computedAt = Date()
    }

    /// Morgen-Einschätzung setzen: Sie zählt als „subjektive Erholung“ zum Score.
    func updateRating(_ record: NightRecord, to value: Int) {
        record.ratingValue = value
        if let components = record.components {
            let updated = SleepScore.applying(rating: value > 0 ? value : nil, to: components)
            record.components = updated
            record.score = updated.total
        }
        classify(record)
    }

    /// Schnitt der letzten 7 Nächte bis und mit `day` – die Hauptanzeige, weil
    /// einzelne Nächte stark schwanken.
    func weekAverage(endingAt day: Date = Date()) -> Double? {
        let end = DayMath.nextDay(of: day, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        let scores = store.nights(from: start, to: end)
            .filter { !$0.excluded }
            .compactMap { night in night.nightDate.map { (day: $0, score: night.score) } }
        return SleepScore.average(of: scores, days: 7, endingAt: day, calendar: calendar)
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
