import Foundation
import Testing
@testable import buschper

@Suite("Kalorienbedarf")
struct EnergyCalculatorTests {
    let calendar = TestCalendar.calendar

    @Test("Mifflin-St Jeor, Mann: 80 kg, 180 cm, 40 Jahre")
    func bmrMale() {
        let bmr = EnergyCalculator.basalMetabolicRate(sex: .male, weightKg: 80, heightCm: 180, age: 40)
        #expect(bmr == 1730)
    }

    @Test("Mifflin-St Jeor, Frau: 60 kg, 165 cm, 35 Jahre")
    func bmrFemale() {
        let bmr = EnergyCalculator.basalMetabolicRate(sex: .female, weightKg: 60, heightCm: 165, age: 35)
        #expect(bmr.isClose(to: 1295.25))
    }

    @Test("Alter wird auf den Geburtstag genau berechnet")
    func age() {
        let birth = TestCalendar.date(1980, 6, 15)
        #expect(EnergyCalculator.age(birthDate: birth, on: TestCalendar.date(2026, 6, 14), calendar: calendar) == 45)
        #expect(EnergyCalculator.age(birthDate: birth, on: TestCalendar.date(2026, 6, 15), calendar: calendar) == 46)
    }

    @Test("Live-Budget: Grundumsatz plus gemessene Aktivkalorien plus Abschlag")
    func liveBudget() {
        let day = TestCalendar.date(2026, 9, 24)
        let budget = EnergyCalculator.budget(
            bmr: 1700, measuredActiveKcal: 600, activityProfile: .light, goalOffset: -500,
            sex: .male, dayStart: day, now: TestCalendar.date(2026, 9, 24, 18), calendar: calendar
        )
        #expect(budget.total == 1800)
        #expect(!budget.activeIsEstimate)
        #expect(!budget.minimumApplied)
    }

    @Test("Morgens ohne Aktivdaten: noch keine Schätzung")
    func morningWithoutData() {
        let day = TestCalendar.date(2026, 9, 24)
        let budget = EnergyCalculator.budget(
            bmr: 1700, measuredActiveKcal: nil, activityProfile: .moderate, goalOffset: 0,
            sex: .male, dayStart: day, now: TestCalendar.date(2026, 9, 24, 8), calendar: calendar
        )
        #expect(budget.activeKcal == 0)
        #expect(!budget.activeIsEstimate)
        #expect(budget.total == 1700)
    }

    @Test("Ab 12:00 ohne Aktivdaten springt das Bewegungsprofil ein")
    func fallbackAfterNoon() {
        let day = TestCalendar.date(2026, 9, 24)
        let budget = EnergyCalculator.budget(
            bmr: 1700, measuredActiveKcal: 0, activityProfile: .moderate, goalOffset: 0,
            sex: .male, dayStart: day, now: TestCalendar.date(2026, 9, 24, 12), calendar: calendar
        )
        #expect(budget.activeIsEstimate)
        #expect(budget.activeKcal.isClose(to: 935))
        #expect(budget.total.isClose(to: 2635))
    }

    @Test("Vergangene Tage ohne Aktivdaten gelten als abgeschlossen: Schätzung")
    func fallbackPastDay() {
        let day = TestCalendar.date(2026, 9, 20)
        let budget = EnergyCalculator.budget(
            bmr: 1500, measuredActiveKcal: nil, activityProfile: .sedentary, goalOffset: 0,
            sex: .female, dayStart: day, now: TestCalendar.date(2026, 9, 24, 7), calendar: calendar
        )
        #expect(budget.activeIsEstimate)
        #expect(budget.activeKcal.isClose(to: 300))
    }

    @Test("Untergrenze greift, wenn der Abschlag zu gross ist")
    func minimum() {
        let day = TestCalendar.date(2026, 9, 24)
        let budget = EnergyCalculator.budget(
            bmr: 1300, measuredActiveKcal: 0, activityProfile: .light, goalOffset: -500,
            sex: .female, dayStart: day, now: TestCalendar.date(2026, 9, 24, 7), calendar: calendar
        )
        #expect(budget.total == 1200)
        #expect(budget.minimumApplied)
    }

    @Test("Hinweis auf neuen Bedarf erst ab mehr als 20 kcal Unterschied")
    func notableChange() {
        #expect(!EnergyCalculator.bmrChangeIsNotable(old: 1700, new: 1715))
        #expect(EnergyCalculator.bmrChangeIsNotable(old: 1700, new: 1725))
    }
}

@Suite("Makroziele")
struct MacroTargetsTests {
    @Test("Standardverteilung 45 / 25 / 30 ist gültig")
    func standardIsValid() {
        #expect(MacroSplit.standard.isValid)
    }

    @Test("Summe ungleich 100 ist ungültig")
    func invalidSum() {
        #expect(!MacroSplit(carbsPercent: 50, proteinPercent: 30, fatPercent: 30).isValid)
        #expect(!MacroSplit(carbsPercent: -10, proteinPercent: 80, fatPercent: 30).isValid)
    }

    @Test("2000 kcal mit Standardverteilung ergeben 225 g KH, 125 g Eiweiss, 66.7 g Fett")
    func grams() {
        let targets = MacroTargets.from(kcalBudget: 2000, split: .standard, fiberMinG: 30)
        #expect(targets.carbsG == 225)
        #expect(targets.proteinG == 125)
        #expect(targets.fatG.isClose(to: 66.67))
        #expect(targets.fiberMinG == 30)
    }
}
