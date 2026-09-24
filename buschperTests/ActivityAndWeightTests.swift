import Foundation
import Testing
@testable import buschper

@Suite("Aktivität")
struct ActivityTests {
    @Test("Stufen nach Schritten", arguments: [
        (0.0, ActivityLevel.low),
        (4_999, .low),
        (5_000, .light),
        (7_499, .light),
        (7_500, .moderate),
        (9_999, .moderate),
        (10_000, .active),
        (25_000, .active)
    ])
    func levels(steps: Double, expected: ActivityLevel) {
        #expect(ActivityLevel(steps: steps) == expected)
    }

    @Test("MET-Schätzung: 1 h Joggen mittel bei 70 kg")
    func metEstimate() {
        #expect(WorkoutEstimator.kcal(sport: .running, intensity: .moderate, weightKg: 70, durationMinutes: 60) == 686)
    }

    @Test("Nur „hert“ zählt als intensiv")
    func intensity() {
        #expect(WorkoutIntensity.hard.isIntense)
        #expect(!WorkoutIntensity.moderate.isIntense)
    }

    @Test("Jede Sportart hat steigende MET-Werte")
    func metOrder() {
        for sport in SportType.allCases {
            #expect(sport.met(.light) < sport.met(.moderate))
            #expect(sport.met(.moderate) < sport.met(.hard))
        }
    }
}

@Suite("Gewicht")
struct WeightMathTests {
    let calendar = TestCalendar.calendar

    @Test("Pro Tag gilt die tiefste Messung")
    func dailyMinimum() {
        let samples = [
            WeightSample(date: TestCalendar.date(2026, 9, 20, 7), kg: 80.2),
            WeightSample(date: TestCalendar.date(2026, 9, 20, 20), kg: 81.0),
            WeightSample(date: TestCalendar.date(2026, 9, 21, 7), kg: 80.0)
        ]
        let daily = WeightMath.daily(samples, calendar: calendar)
        #expect(daily.count == 2)
        #expect(daily[0].kg == 80.2)
        #expect(daily[1].kg == 80.0)
    }

    @Test("7-Tage-Schnitt nimmt nur die Tage im Fenster")
    func sevenDayAverage() {
        let daily = [
            DailyWeight(day: TestCalendar.date(2026, 9, 10), kg: 90),
            DailyWeight(day: TestCalendar.date(2026, 9, 18), kg: 80),
            DailyWeight(day: TestCalendar.date(2026, 9, 24), kg: 79)
        ]
        let average = WeightMath.average(daily, days: 7, endingAt: TestCalendar.date(2026, 9, 24, 12), calendar: calendar)
        #expect(average == 80 - 0.5)
    }

    @Test("Ohne Werte im Fenster gibt es keinen Schnitt")
    func noAverage() {
        let daily = [DailyWeight(day: TestCalendar.date(2026, 8, 1), kg: 80)]
        #expect(WeightMath.average(daily, endingAt: TestCalendar.date(2026, 9, 24), calendar: calendar) == nil)
    }

    @Test("Veränderung vom ersten zum letzten Wert")
    func change() {
        let daily = [
            DailyWeight(day: TestCalendar.date(2026, 9, 1), kg: 70.3),
            DailyWeight(day: TestCalendar.date(2026, 9, 24), kg: 68.8)
        ]
        #expect((WeightMath.change(daily) ?? 0).isClose(to: -1.5))
        #expect(WeightMath.change([daily[0]]) == nil)
    }
}
