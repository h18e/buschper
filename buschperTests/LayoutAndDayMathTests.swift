import Foundation
import Testing
@testable import buschper

@Suite("Dashboard-Anordnung")
struct DashboardLayoutTests {
    @Test("Ausgeblendete Karten fehlen in der Anzeige")
    func hidden() {
        var layout = DashboardLayout.standard
        layout.setVisible(.weight, false)
        #expect(!layout.visibleCards.contains(.weight))
        layout.setVisible(.weight, true)
        #expect(layout.visibleCards.contains(.weight))
    }

    @Test("Verschieben wie bei SwiftUI onMove")
    func move() {
        var layout = DashboardLayout(order: [.energy, .dayLog, .fluid], hidden: [])
        layout.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(Array(layout.order.prefix(3)) == [.fluid, .energy, .dayLog])
        layout.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(Array(layout.order.prefix(3)) == [.energy, .dayLog, .fluid])
    }

    @Test("Neue Karten einer späteren Version erscheinen hinten")
    func normalization() {
        let old = DashboardLayout(order: [.fluid, .energy], hidden: [])
        let normalized = old.normalized
        #expect(normalized.order.first == .fluid)
        #expect(Set(normalized.order) == Set(DashboardCard.allCases))
        #expect(normalized.order.count == DashboardCard.allCases.count)
    }

    @Test("Speichern und Laden, kaputte Daten ergeben den Standard")
    func persistence() {
        var layout = DashboardLayout.standard
        layout.setVisible(.sleep, false)
        #expect(DashboardLayout.decode(layout.jsonString) == layout)
        #expect(DashboardLayout.decode("kaputt") == .standard)
    }
}

@Suite("Tage und Nächte")
struct DayMathTests {
    let calendar = TestCalendar.calendar

    @Test("Die Nacht gehört zum Tag des Aufwachens, der Vortag ist der Tag davor")
    func nightAssignment() {
        let wake = TestCalendar.date(2026, 9, 24, 6, 45)
        let night = DayMath.nightDay(forWake: wake, calendar: calendar)
        #expect(night == TestCalendar.date(2026, 9, 24))
        #expect(DayMath.previousDay(of: night, calendar: calendar) == TestCalendar.date(2026, 9, 23))
    }

    @Test("Minuten nach Mitternacht laufen über 1440 hinaus")
    func minutesPastMidnight() {
        let day = TestCalendar.date(2026, 9, 23)
        let late = TestCalendar.date(2026, 9, 24, 0, 30)
        #expect(DayMath.minutes(of: late, sinceStartOf: day, calendar: calendar) == 1470)
    }

    @Test("Einschlafzeiten um Mitternacht herum bleiben vergleichbar")
    func sinceNoon() {
        #expect(DayMath.minutesSinceNoon(TestCalendar.date(2026, 9, 23, 23, 0), calendar: calendar) == 660)
        #expect(DayMath.minutesSinceNoon(TestCalendar.date(2026, 9, 24, 1, 0), calendar: calendar) == 780)
    }

    @Test("Median und Durchschnitt")
    func statistics() {
        #expect(DayMath.median([3, 1, 2]) == 2)
        #expect(DayMath.median([4, 1, 2, 3]) == 2.5)
        #expect(DayMath.median([]) == nil)
        #expect(DayMath.average([1, 2, 3]) == 2)
    }

    @Test("Tagesliste inklusive Anfang und Ende")
    func dayRange() {
        let days = DayMath.days(from: TestCalendar.date(2026, 9, 22, 15), through: TestCalendar.date(2026, 9, 24, 8), calendar: calendar)
        #expect(days.count == 3)
    }
}
