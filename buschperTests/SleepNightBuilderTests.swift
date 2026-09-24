import Foundation
import Testing
@testable import buschper

@Suite("Nacht aus Health-Daten")
struct SleepNightBuilderTests {
    private func sample(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int,
                        _ stage: SleepStage, source: String = "watch", nextDayStart: Bool = false, nextDayEnd: Bool = true) -> HealthSleepSample {
        HealthSleepSample(
            start: TestCalendar.date(2026, 9, nextDayStart ? 24 : 23, startHour, startMinute),
            end: TestCalendar.date(2026, 9, nextDayEnd ? 24 : 23, endHour, endMinute),
            stage: stage,
            sourceId: source
        )
    }

    @Test("Phasen der Uhr ergeben Schlafzeit, Tief, REM und Wachzeit")
    func watchNight() throws {
        let samples = [
            sample(23, 0, 1, 0, .core, nextDayEnd: true).with(startDay: 23),
            sample(1, 0, 2, 0, .deep, nextDayStart: true),
            sample(2, 0, 2, 20, .awake, nextDayStart: true),
            sample(2, 20, 4, 0, .rem, nextDayStart: true),
            sample(4, 0, 7, 0, .core, nextDayStart: true)
        ]
        let night = try #require(SleepNightBuilder.build(from: samples))
        #expect(night.asleepMinutes == 460)
        #expect(night.deepMinutes == 60)
        #expect(night.remMinutes == 100)
        #expect(night.awakeMinutes == 20)
        #expect(night.hasStages)
    }

    @Test("Die Quelle mit Phasen gewinnt gegen eine längere ohne Phasen")
    func prefersStages() throws {
        let samples = [
            sample(22, 0, 7, 0, .asleep, source: "iphone").with(startDay: 23),
            sample(23, 0, 6, 0, .core, source: "watch").with(startDay: 23)
        ]
        let night = try #require(SleepNightBuilder.build(from: samples))
        #expect(night.hasStages)
        #expect(night.asleepMinutes == 420)
    }

    @Test("Ein Nickerchen am Abend zählt nicht zur Nacht")
    func napIgnored() throws {
        let samples = [
            HealthSleepSample(start: TestCalendar.date(2026, 9, 23, 19, 0), end: TestCalendar.date(2026, 9, 23, 19, 40), stage: .asleep, sourceId: "a"),
            HealthSleepSample(start: TestCalendar.date(2026, 9, 23, 23, 30), end: TestCalendar.date(2026, 9, 24, 6, 30), stage: .asleep, sourceId: "a")
        ]
        let night = try #require(SleepNightBuilder.build(from: samples))
        #expect(night.asleepMinutes == 420)
        #expect(night.sleepOnset == TestCalendar.date(2026, 9, 23, 23, 30))
        #expect(!night.hasStages)
    }

    @Test("Überlappende Abschnitte werden nicht doppelt gezählt")
    func overlaps() throws {
        let samples = [
            HealthSleepSample(start: TestCalendar.date(2026, 9, 23, 23, 0), end: TestCalendar.date(2026, 9, 24, 3, 0), stage: .asleep, sourceId: "a"),
            HealthSleepSample(start: TestCalendar.date(2026, 9, 24, 2, 0), end: TestCalendar.date(2026, 9, 24, 6, 0), stage: .asleep, sourceId: "a")
        ]
        let night = try #require(SleepNightBuilder.build(from: samples))
        #expect(night.asleepMinutes == 420)
    }

    @Test("Weniger als eine Stunde ist keine Nacht")
    func tooShort() {
        let samples = [
            HealthSleepSample(start: TestCalendar.date(2026, 9, 24, 1, 0), end: TestCalendar.date(2026, 9, 24, 1, 45), stage: .asleep, sourceId: "a")
        ]
        #expect(SleepNightBuilder.build(from: samples) == nil)
    }

    @Test("Suchfenster: Vortag 18:00 bis 14:00")
    func window() {
        let window = SleepNightBuilder.window(for: TestCalendar.date(2026, 9, 24), calendar: TestCalendar.calendar)
        #expect(window.start == TestCalendar.date(2026, 9, 23, 18))
        #expect(window.end == TestCalendar.date(2026, 9, 24, 14))
    }
}

private extension HealthSleepSample {
    /// Startet am angegebenen Septembertag statt am Folgetag.
    func with(startDay: Int) -> HealthSleepSample {
        var copy = self
        let components = TestCalendar.calendar.dateComponents([.hour, .minute], from: start)
        copy.start = TestCalendar.date(2026, 9, startDay, components.hour ?? 0, components.minute ?? 0)
        return copy
    }
}
