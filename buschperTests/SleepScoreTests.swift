import Foundation
import Testing
@testable import buschper

@Suite("Schlafscore")
struct SleepScoreTests {
    let calendar = TestCalendar.calendar

    /// Nacht ab 23:00 mit `asleep` Minuten Schlaf und `waso` Minuten wach dazwischen.
    private func night(
        asleep: Double = 480,
        waso: Double = 10,
        awakenings: Int = 1,
        latency: Double? = 10
    ) -> SleepNight {
        let onset = TestCalendar.date(2026, 9, 23, 23, 0)
        let wake = onset.addingTimeInterval((asleep + waso) * 60)
        return SleepNight(
            sleepOnset: onset, wake: wake, asleepMinutes: asleep,
            deepMinutes: nil, remMinutes: nil, coreMinutes: nil, awakeMinutes: waso,
            bedStart: latency.map { onset.addingTimeInterval(-$0 * 60) }, bedEnd: latency == nil ? nil : wake,
            awakenings: awakenings
        )
    }

    /// Schlafmitte der Testnacht in Minuten seit Mittag.
    private func midpoint(_ night: SleepNight) -> Double {
        SleepScore.midpointSinceNoon(onset: night.sleepOnset, wake: night.wake, calendar: calendar)
    }

    @Test("Beispielnacht aus der Vorlage ergibt 77 Punkte")
    func exampleNight() {
        // 6 h 40 Schlaf, 20 min Einschlafen, 30 min wach, 2 Aufwachphasen,
        // Schlafmitte 45 min neben dem Wochenschnitt, Erholung 3/5
        let example = night(asleep: 400, waso: 30, awakenings: 2, latency: 20)
        let score = SleepScore.score(night: example, previousMidpoints: [midpoint(example) - 45], rating: 3, calendar: calendar)
        #expect(score.duration.isClose(to: 29.17))
        #expect(score.latency == 8)
        #expect(score.waso.isClose(to: 4.19))
        #expect(score.awakenings.isClose(to: 4))
        #expect(score.efficiency == 8)
        #expect((score.regularity ?? -1).isClose(to: 18.75))
        #expect(score.recovery == 5)
        #expect(score.total == 77.1)
        #expect(SleepGrade(score: score.total) == .solid)
    }

    @Test("Alles im grünen Bereich ergibt 100")
    func perfect() {
        let good = night()
        let score = SleepScore.score(night: good, previousMidpoints: [midpoint(good)], rating: 5, calendar: calendar)
        #expect(score.total == 100)
        #expect(score.continuity == 30)
    }

    @Test("Dauer: unter 5 h nichts, 6 h die Hälfte, 7–9.5 h voll, länger leichter Abzug")
    func duration() {
        #expect(SleepScore.durationPoints(asleepMinutes: 4.5 * 60) == 0)
        #expect(SleepScore.durationPoints(asleepMinutes: 6 * 60) == 17.5)
        #expect(SleepScore.durationPoints(asleepMinutes: 7 * 60) == 35)
        #expect(SleepScore.durationPoints(asleepMinutes: 9.5 * 60) == 35)
        #expect(SleepScore.durationPoints(asleepMinutes: 10.25 * 60) == 32.5)
        #expect(SleepScore.durationPoints(asleepMinutes: 12 * 60) == 30)
    }

    @Test("Kontinuität: Schwellen der NSF")
    func continuity() {
        let bad = night(asleep: 480, waso: 41, awakenings: 4, latency: 45)
        let score = SleepScore.score(night: bad, previousMidpoints: [], rating: nil, calendar: calendar)
        #expect(score.latency == 0)
        #expect(score.waso == 0)
        #expect(score.awakenings == 0)
        // 480 ÷ (45 + 480 + 41) = 84.8 % → knapp unter voll
        #expect(score.efficiency < 8 && score.efficiency > 7)
    }

    @Test("Effizienz ohne „Im Bett“: Schlaf ÷ Einschlafen bis Aufwachen")
    func efficiencyWithoutBed() {
        let noBed = night(asleep: 370, waso: 130, latency: nil)
        #expect(noBed.latencyMinutes == nil)
        #expect(noBed.efficiencyPercent == 74)
        let score = SleepScore.score(night: noBed, previousMidpoints: [], rating: nil, calendar: calendar)
        #expect(score.latency == nil)
        #expect(score.efficiency == 0)
    }

    @Test("Fehlende Teile werden auf 100 hochgerechnet")
    func missingParts() {
        let score = SleepScore.score(night: night(latency: nil), previousMidpoints: [], rating: nil, calendar: calendar)
        #expect(score.latency == nil)
        #expect(score.regularity == nil)
        #expect(score.recovery == nil)
        #expect(score.total == 100)
    }

    @Test("Regelmässigkeit: Schnitt der letzten 7 Schlafmitten")
    func regularity() {
        let tonight = night()
        let mid = midpoint(tonight)
        // Ältere Nächte zählen nicht: nur die letzten 7, alle 60 min daneben
        let history = [mid - 300, mid - 300] + Array(repeating: mid - 60, count: 7)
        let score = SleepScore.score(night: tonight, previousMidpoints: history, rating: nil, calendar: calendar)
        #expect(score.midpointDeviationMinutes == 60)
        #expect(score.regularity == 12.5)
    }

    @Test("Morgen-Einschätzung nachträglich: Erholung und Total neu")
    func rating() {
        let base = SleepScore.score(night: night(), previousMidpoints: [], rating: nil, calendar: calendar)
        let worst = SleepScore.applying(rating: 1, to: base)
        #expect(worst.recovery == 0)
        #expect(worst.total < base.total)
        let best = SleepScore.applying(rating: 5, to: worst)
        #expect(best.recovery == 10)
        #expect(best.total == 100)
        #expect(SleepScore.applying(rating: nil, to: best).recovery == nil)
    }

    @Test("Einstufung")
    func grades() {
        #expect(SleepGrade(score: 85) == .good)
        #expect(SleepGrade(score: 84.9) == .solid)
        #expect(SleepGrade(score: 70) == .solid)
        #expect(SleepGrade(score: 69) == .limited)
        #expect(SleepGrade(score: 50) == .limited)
        #expect(SleepGrade(score: 49.9) == .poor)
    }

    @Test("7-Tage-Schnitt nimmt nur die letzten 7 Tage")
    func weekAverage() {
        let today = TestCalendar.date(2026, 9, 30)
        let scores: [(day: Date, score: Double)] = (0..<10).map { offset in
            (day: calendar.date(byAdding: .day, value: -offset, to: today)!, score: offset < 7 ? 80 : 20)
        }
        #expect(SleepScore.average(of: scores, endingAt: today, calendar: calendar) == 80)
    }

    @Test("Auswertungen der alten Fassung werden nicht falsch gelesen")
    func oldComponents() {
        let json = #"{"duration":40,"deep":20,"rem":15,"awake":15,"regularity":10,"total":100}"#
        #expect((try? JSONDecoder().decode(SleepScoreComponents.self, from: Data(json.utf8))) == nil)
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
