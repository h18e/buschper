import Foundation
import Testing
@testable import buschper

@Suite("Schlafscore")
struct SleepScoreTests {
    let calendar = TestCalendar.calendar

    private func night(
        asleep: Double = 480,
        deep: Double? = 80,
        rem: Double? = 100,
        awake: Double = 5,
        onsetHour: Int = 23,
        onsetMinute: Int = 0
    ) -> SleepNight {
        let onset = TestCalendar.date(2026, 9, 23, onsetHour, onsetMinute)
        return SleepNight(
            sleepOnset: onset,
            wake: onset.addingTimeInterval((asleep + awake) * 60),
            asleepMinutes: asleep,
            deepMinutes: deep,
            remMinutes: rem,
            coreMinutes: deep.flatMap { d in rem.map { asleep - d - $0 } },
            awakeMinutes: awake
        )
    }

    /// Einschlafzeit 23:00 in Minuten seit Mittag.
    private let medianAt2300 = 660.0

    @Test("Perfekte Nacht ergibt 100")
    func perfect() {
        let score = SleepScore.score(night: night(), sleepGoalMinutes: 480, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.total == 100)
        #expect(score.duration == 40)
        #expect(score.deep == 20)
        #expect(score.rem == 15)
        #expect(score.awake == 15)
        #expect(score.regularity == 10)
    }

    @Test("Halbe Schlafzeit gibt für die Dauer keine Punkte")
    func halfDuration() {
        let score = SleepScore.score(night: night(asleep: 240, deep: 40, rem: 50), sleepGoalMinutes: 480, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.duration == 0)
        #expect(score.total == 60)
    }

    @Test("Dreiviertel der Schlafzeit gibt die Hälfte der Dauer-Punkte")
    func threeQuarterDuration() {
        let score = SleepScore.score(night: night(asleep: 360, deep: 60, rem: 75), sleepGoalMinutes: 480, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.duration == 20)
    }

    @Test("35 Minuten wach geben die Hälfte der Wach-Punkte")
    func awakePartial() {
        let score = SleepScore.score(night: night(awake: 35), sleepGoalMinutes: 480, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.awake == 7.5)
    }

    @Test("Ohne Phasen werden die übrigen Gewichte hochgerechnet")
    func withoutStages() {
        let score = SleepScore.score(night: night(deep: nil, rem: nil), sleepGoalMinutes: 480, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.deep == nil)
        #expect(score.rem == nil)
        #expect(score.total == 100)
    }

    @Test("Ohne Vorgeschichte fällt die Regelmässigkeit weg")
    func withoutHistory() {
        let score = SleepScore.score(night: night(), sleepGoalMinutes: 480, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(score.regularity == nil)
        #expect(score.total == 100)
    }

    @Test("Einschlafen nach Mitternacht wird korrekt mit dem Median verglichen")
    func regularityAcrossMidnight() {
        // Median 23:30, Einschlafen 00:15 → 45 Minuten Abweichung
        let onset = TestCalendar.date(2026, 9, 24, 0, 15)
        let late = SleepNight(sleepOnset: onset, wake: onset.addingTimeInterval(8 * 3600), asleepMinutes: 480,
                              deepMinutes: 80, remMinutes: 100, coreMinutes: 300, awakeMinutes: 0)
        let score = SleepScore.score(night: late, sleepGoalMinutes: 480, medianOnsetSinceNoon: 690, calendar: calendar)
        let expected = (1 - (45.0 - 15) / (90 - 15)) * 10
        #expect((score.regularity ?? -1).isClose(to: expected))
    }

    @Test("Zu wenig Tiefschlaf kostet Punkte, zu viel nicht")
    func deepSleepBounds() {
        let low = SleepScore.score(night: night(deep: 24), sleepGoalMinutes: 480, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(low.deep == 0)
        let high = SleepScore.score(night: night(deep: 160, rem: 100), sleepGoalMinutes: 480, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(high.deep == 20)
    }

    @Test("Hilfsfunktionen steigen und fallen linear")
    func rampHelpers() {
        #expect(SleepScore.rise(9, zeroAt: 5, fullAt: 13) == 0.5)
        #expect(SleepScore.fall(35, fullUntil: 10, zeroFrom: 60) == 0.5)
    }
}

@Suite("Schlechte Nacht")
struct NightClassifierTests {
    let rules = BadNightRules.standard

    @Test("Score unter 60 ist schlecht")
    func absolute() {
        #expect(NightClassifier.reasons(score: 59, average30: nil, rating: nil, rules: rules) == [.lowScore])
        #expect(!NightClassifier.isBad(score: 60, average30: nil, rating: nil, rules: rules))
    }

    @Test("10 Punkte unter dem eigenen Schnitt ist schlecht")
    func relative() {
        #expect(NightClassifier.reasons(score: 72, average30: 82, rating: nil, rules: rules) == [.belowAverage])
        #expect(!NightClassifier.isBad(score: 73, average30: 82, rating: nil, rules: rules))
    }

    @Test("1 oder 2 Sterne sind schlecht, 0 heisst keine Angabe")
    func rating() {
        #expect(NightClassifier.isBad(score: 90, average30: 85, rating: 2, rules: rules))
        #expect(!NightClassifier.isBad(score: 90, average30: 85, rating: 3, rules: rules))
        #expect(!NightClassifier.isBad(score: 90, average30: 85, rating: 0, rules: rules))
    }

    @Test("Mehrere Gründe werden alle genannt")
    func multiple() {
        let reasons = NightClassifier.reasons(score: 50, average30: 80, rating: 1, rules: rules)
        #expect(reasons == [.lowScore, .belowAverage, .feltBad])
    }
}
