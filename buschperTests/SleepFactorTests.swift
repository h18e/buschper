import Foundation
import Testing
@testable import buschper

@Suite("Schlaf-Faktoren")
struct SleepFactorTests {
    let calendar = TestCalendar.calendar
    let day = TestCalendar.date(2026, 9, 23)
    let thresholds = FactorThresholds.standard

    @Test("Ein unauffälliger Tag löst nichts aus")
    func quietDay() {
        let metrics = DayMetrics(
            kcalEaten: 2000, kcalBudget: 2100, dinnerKcal: 600, dinnerFatG: 20,
            lastMealMinute: 19 * 60, alcoholG: 0, caffeineMg: 80, lastCaffeineMinute: 10 * 60,
            fluidMl: 2300, fluidGoalMl: 2500, steps: 9000, stepsAverage30: 8000
        )
        #expect(FactorEvaluator.factors(for: metrics, thresholds: thresholds).isEmpty)
    }

    @Test("Jeder Faktor einzeln")
    func eachFactor() {
        func factors(_ metrics: DayMetrics) -> Set<SleepFactor> {
            FactorEvaluator.factors(for: metrics, thresholds: thresholds)
        }
        #expect(factors(DayMetrics(alcoholG: 10)) == [.alcohol])
        #expect(factors(DayMetrics(caffeineMg: 60, lastCaffeineMinute: 15 * 60)) == [.lateCaffeine])
        #expect(factors(DayMetrics(lastMealMinute: 20 * 60 + 30)) == [.lateMeal])
        #expect(factors(DayMetrics(kcalEaten: 2000, dinnerKcal: 900, dinnerFatG: 10)) == [.heavyDinner])
        #expect(factors(DayMetrics(kcalEaten: 1000, kcalBudget: 2000)).contains(.calorieImbalance))
        #expect(factors(DayMetrics(fluidMl: 1000, fluidGoalMl: 2500)) == [.lowFluid])
        #expect(factors(DayMetrics(steps: 3000, stepsAverage30: 8000)) == [.lowActivity])
    }

    @Test("Fettes Znacht: über 40 % der Znacht-kcal aus Fett")
    func fattyDinner() {
        // 600 kcal, 30 g Fett = 270 kcal = 45 %
        let metrics = DayMetrics(kcalEaten: 2400, dinnerKcal: 600, dinnerFatG: 30)
        #expect(FactorEvaluator.factors(for: metrics, thresholds: thresholds) == [.heavyDinner])
    }

    @Test("Intensives Training weniger als 2 h vor dem Einschlafen")
    func lateWorkout() {
        let onset = TestCalendar.date(2026, 9, 23, 23, 0)
        let late = DayMetrics(workouts: [WorkoutSummary(end: TestCalendar.date(2026, 9, 23, 21, 30), isIntense: true)], sleepOnset: onset)
        #expect(FactorEvaluator.factors(for: late, thresholds: thresholds) == [.lateWorkout])

        let early = DayMetrics(workouts: [WorkoutSummary(end: TestCalendar.date(2026, 9, 23, 20, 30), isIntense: true)], sleepOnset: onset)
        #expect(FactorEvaluator.factors(for: early, thresholds: thresholds).isEmpty)

        let gentle = DayMetrics(workouts: [WorkoutSummary(end: TestCalendar.date(2026, 9, 23, 22, 30), isIntense: false)], sleepOnset: onset)
        #expect(FactorEvaluator.factors(for: gentle, thresholds: thresholds).isEmpty)
    }

    @Test("Fehlende Kennzahlen lösen keinen Faktor aus")
    func missingData() {
        #expect(FactorEvaluator.factors(for: DayMetrics(), thresholds: thresholds).isEmpty)
    }

    @Test("Kennzahlen aus Einträgen: Wein nach Mitternacht zählt zum Vortag")
    func builderAfterMidnight() {
        let onset = TestCalendar.date(2026, 9, 24, 1, 0)
        let events = [
            IntakeEvent(time: TestCalendar.date(2026, 9, 23, 12, 0), category: .lunch,
                        nutrients: Nutrients(kcal: 700, fat: 20), isFood: true),
            IntakeEvent(time: TestCalendar.date(2026, 9, 23, 19, 0), category: .dinner,
                        nutrients: Nutrients(kcal: 800, fat: 40), isFood: true),
            IntakeEvent(time: TestCalendar.date(2026, 9, 24, 0, 30), category: nil,
                        nutrients: Nutrients(kcal: 80, alcohol: 10), fluidMl: 0, isFood: false),
            IntakeEvent(time: TestCalendar.date(2026, 9, 23, 16, 0), category: nil,
                        nutrients: Nutrients(kcal: 2, caffeine: 80), fluidMl: 150, isFood: false),
            // Nach dem Einschlafen – gehört nicht mehr dazu.
            IntakeEvent(time: TestCalendar.date(2026, 9, 24, 7, 0), category: .breakfast,
                        nutrients: Nutrients(kcal: 400), isFood: true)
        ]
        let metrics = DayMetricsBuilder.build(
            day: day, events: events, kcalBudget: 2200, fluidGoalMl: 2500,
            steps: 8000, stepsAverage30: 8000, workouts: [], sleepOnset: onset, calendar: calendar
        )
        #expect(metrics.kcalEaten == 1582)
        #expect(metrics.alcoholG == 10)
        #expect(metrics.dinnerKcal == 800)
        #expect(metrics.lastMealMinute == 1140.0)  // 19:00
        #expect(metrics.lastCaffeineMinute == 960.0)  // 16:00
        #expect(metrics.fluidMl == 150)

        let factors = FactorEvaluator.factors(for: metrics, thresholds: thresholds)
        #expect(factors.contains(.alcohol))
        #expect(factors.contains(.lateCaffeine))
        #expect(factors.contains(.heavyDinner))
        #expect(factors.contains(.lowFluid))
        #expect(!factors.contains(.lateMeal))
    }

    @Test("Ein Snack nach 17:30 zählt zum Znacht")
    func lateSnackIsDinner() {
        let events = [
            IntakeEvent(time: TestCalendar.date(2026, 9, 23, 18, 0), category: .snack,
                        nutrients: Nutrients(kcal: 300), isFood: true)
        ]
        let metrics = DayMetricsBuilder.build(
            day: day, events: events, kcalBudget: nil, fluidGoalMl: nil, steps: nil,
            stepsAverage30: nil, workouts: [], sleepOnset: nil, calendar: calendar
        )
        #expect(metrics.dinnerKcal == 300)
    }

    @Test("Kennzahlen überleben das Speichern als JSON")
    func metricsJSON() {
        let original = DayMetrics(kcalEaten: 1800, alcoholG: 12,
                                  workouts: [WorkoutSummary(end: TestCalendar.date(2026, 9, 23, 18), isIntense: true)],
                                  sleepOnset: TestCalendar.date(2026, 9, 23, 23))
        #expect(DayMetrics.decode(original.jsonString) == original)
    }
}

@Suite("Muster")
struct PatternAnalyzerTests {
    private func sample(_ score: Double, _ factors: Set<SleepFactor>, excluded: Bool = false) -> NightSample {
        NightSample(score: score, isBad: score < 60, factors: factors, excluded: excluded)
    }

    @Test("Mit 5 Nächten pro Gruppe entsteht ein verlässliches Muster")
    func reliablePattern() {
        let samples = (0..<5).map { _ in sample(62, [.alcohol]) } + (0..<5).map { _ in sample(76, []) }
        let alcohol = PatternAnalyzer.patterns(from: samples).first { $0.factor == .alcohol }
        #expect(alcohol?.isReliable == true)
        #expect(alcohol?.scoreDrop == 14)
        #expect(alcohol?.nightsWith == 5)
        #expect(alcohol?.nightsWithout == 5)
    }

    @Test("Unter 5 Nächten ist ein Muster noch nicht verlässlich")
    func notEnoughData() {
        let samples = (0..<3).map { _ in sample(50, [.alcohol]) } + (0..<10).map { _ in sample(80, []) }
        let alcohol = PatternAnalyzer.patterns(from: samples).first { $0.factor == .alcohol }
        #expect(alcohol?.isReliable == false)
    }

    @Test("Ausgeschlossene Nächte zählen nicht")
    func excluded() {
        let samples = [sample(40, [.alcohol], excluded: true), sample(80, [])]
        let alcohol = PatternAnalyzer.patterns(from: samples).first { $0.factor == .alcohol }
        #expect(alcohol?.nightsWith == 0)
    }

    @Test("Stärkster Effekt zuerst")
    func sorting() {
        var samples: [NightSample] = []
        samples += (0..<5).map { _ in sample(70, [.lateMeal]) }
        samples += (0..<5).map { _ in sample(50, [.alcohol]) }
        samples += (0..<5).map { _ in sample(80, []) }
        let patterns = PatternAnalyzer.patterns(from: samples)
        #expect(patterns.first?.factor == .alcohol)
        #expect(patterns.dropFirst().first?.factor == .lateMeal)
    }
}
