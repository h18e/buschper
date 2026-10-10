import Foundation
import Testing
@testable import buschper

@Suite("Schlafscore")
struct SleepScoreTests {
    let calendar = TestCalendar.calendar

    /// Ausgewogene Nacht nach den Richtwerten: 475 min, davon Tief 19 %,
    /// REM 22 %, Leicht 56 %, Wach 3 %.
    private func night(
        deep: Double? = 90,
        rem: Double? = 105,
        core: Double? = 265,
        asleep: Double? = nil,
        awake: Double = 15,
        onsetHour: Int = 23,
        onsetMinute: Int = 0
    ) -> SleepNight {
        let onset = TestCalendar.date(2026, 9, 23, onsetHour, onsetMinute)
        let sleep = asleep ?? ((deep ?? 0) + (rem ?? 0) + (core ?? 0))
        return SleepNight(
            sleepOnset: onset,
            wake: onset.addingTimeInterval((sleep + awake) * 60),
            asleepMinutes: sleep,
            deepMinutes: deep,
            remMinutes: rem,
            coreMinutes: core,
            awakeMinutes: awake
        )
    }

    /// Einschlafzeit 23:00 in Minuten seit Mittag.
    private let medianAt2300 = 660.0

    @Test("Ausgewogene Nacht nach den Richtwerten ergibt 100")
    func perfect() {
        let score = SleepScore.score(night: night(), sleepGoalMinutes: 460, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.total == 100)
        #expect(score.duration == 35)
        #expect(score.deep == 20)
        #expect(score.rem == 15)
        #expect(score.light == 10)
        #expect(score.awake == 10)
        #expect(score.regularity == 10)
    }

    @Test("Halbe Schlafzeit gibt für die Dauer keine Punkte")
    func halfDuration() {
        let score = SleepScore.score(night: night(), sleepGoalMinutes: 920, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.duration == 0)
        #expect(score.total == 65)
    }

    @Test("Dreiviertel der Schlafzeit gibt die Hälfte der Dauer-Punkte")
    func threeQuarterDuration() {
        let score = SleepScore.score(night: night(), sleepGoalMinutes: 460 / 0.75, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.duration.isClose(to: 17.5))
    }

    @Test("Wach: unter 5 % voll, 12.5 % halb, ab 20 % nichts")
    func awakeShares() {
        // 60 von 480 Minuten = 12.5 %
        let half = SleepScore.score(night: night(deep: 84, rem: 105, core: 231, awake: 60), sleepGoalMinutes: 420, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(half.awake == 5)
        // 100 von 500 Minuten = 20 %
        let none = SleepScore.score(night: night(deep: 80, rem: 90, core: 230, awake: 100), sleepGoalMinutes: 400, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(none.awake == 0)
    }

    @Test("Tiefschlaf: zu wenig kostet Punkte, zu viel nicht")
    func deepBand() {
        // 4 % → 0
        let low = SleepScore.score(night: night(deep: 20, rem: 110, core: 370, awake: 0), sleepGoalMinutes: 500, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(low.deep == 0)
        // 10 % → halbe Punkte (null bis 5 %, voll ab 15 %)
        let half = SleepScore.score(night: night(deep: 40, rem: 90, core: 270, awake: 0), sleepGoalMinutes: 400, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect((half.deep ?? -1).isClose(to: 10))
        // 32.5 % → über dem Ziel, trotzdem voll
        let high = SleepScore.score(night: night(deep: 130, rem: 90, core: 180, awake: 0), sleepGoalMinutes: 400, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(high.deep == 20)
    }

    @Test("Leichtschlaf über 60 % gibt volle Punkte")
    func lightBand() {
        let score = SleepScore.score(night: night(deep: 60, rem: 80, core: 350, awake: 10), sleepGoalMinutes: 490, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(score.light == 10)
    }

    @Test("Zielbereich: voll ab dem Richtwert, darunter linear")
    func band() {
        let band = SleepBand(zeroBelow: 5, low: 15, high: 25)
        #expect(band.share(20) == 1)
        #expect(band.share(10) == 0.5)
        #expect(band.share(32.5) == 1)
        #expect(band.share(3) == 0)
        #expect(band.share(60) == 1)
    }

    @Test("Ohne Phasen werden die übrigen Gewichte hochgerechnet")
    func withoutStages() {
        let score = SleepScore.score(night: night(deep: nil, rem: nil, core: nil, asleep: 460), sleepGoalMinutes: 460, medianOnsetSinceNoon: medianAt2300, calendar: calendar)
        #expect(score.deep == nil)
        #expect(score.rem == nil)
        #expect(score.light == nil)
        #expect(score.total == 100)
    }

    @Test("Ohne Vorgeschichte fällt die Regelmässigkeit weg")
    func withoutHistory() {
        let score = SleepScore.score(night: night(), sleepGoalMinutes: 460, medianOnsetSinceNoon: nil, calendar: calendar)
        #expect(score.regularity == nil)
        #expect(score.total == 100)
    }

    @Test("Einschlafen nach Mitternacht wird korrekt mit dem Median verglichen")
    func regularityAcrossMidnight() {
        // Median 23:30, Einschlafen 00:15 → 45 Minuten Abweichung
        let onset = TestCalendar.date(2026, 9, 24, 0, 15)
        let late = SleepNight(sleepOnset: onset, wake: onset.addingTimeInterval(8 * 3600), asleepMinutes: 480,
                              deepMinutes: 90, remMinutes: 110, coreMinutes: 280, awakeMinutes: 0)
        let score = SleepScore.score(night: late, sleepGoalMinutes: 480, medianOnsetSinceNoon: 690, calendar: calendar)
        let expected = (1 - (45.0 - 15) / (90 - 15)) * 10
        #expect((score.regularity ?? -1).isClose(to: expected))
    }

    @Test("Ältere Auswertungen ohne Leichtschlaf lassen sich noch lesen")
    func decodesOldComponents() throws {
        let json = #"{"duration":40,"deep":20,"rem":15,"awake":15,"regularity":10,"total":100}"#
        let old = try JSONDecoder().decode(SleepScoreComponents.self, from: Data(json.utf8))
        #expect(old.light == nil)
        #expect(old.total == 100)
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

    @Test("Phasen in Prozent ergeben zusammen genau 100")
    func stagePercentages() {
        #expect(SleepStageShares.percentages([65, 95, 260, 30]) == [14, 21, 58, 7])
        #expect(SleepStageShares.percentages([1, 1, 1]).reduce(0, +) == 100)
        #expect(SleepStageShares.percentages([0, 0]) == [0, 0])
        #expect(SleepStageShares.shareOfNight(84, nightMinutes: 420) == 20)
        #expect(SleepStageShares.shareOfNight(nil, nightMinutes: 420) == nil)
    }
}
