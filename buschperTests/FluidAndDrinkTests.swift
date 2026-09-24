import Foundation
import Testing
@testable import buschper

@Suite("Trinken")
struct FluidAndDrinkTests {
    @Test("35 ml pro kg, auf 50 ml gerundet")
    func baseGoal() {
        #expect(FluidCalculator.goalMl(weightKg: 70, trainingMinutes: 0, overrideMl: nil) == 2450)
        #expect(FluidCalculator.goalMl(weightKg: 73, trainingMinutes: 0, overrideMl: nil) == 2550)
    }

    @Test("Plus 500 ml pro Trainingsstunde")
    func trainingAddsFluid() {
        #expect(FluidCalculator.goalMl(weightKg: 70, trainingMinutes: 90, overrideMl: nil) == 3200)
    }

    @Test("Von Hand gesetztes Ziel übersteuert die Formel")
    func override() {
        #expect(FluidCalculator.goalMl(weightKg: 70, trainingMinutes: 60, overrideMl: 2000) == 2000)
        #expect(FluidCalculator.goalMl(weightKg: 70, trainingMinutes: 0, overrideMl: 0) == 2450)
    }

    @Test("Alkohol in Gramm: 5 dl Bier mit 5 %")
    func alcoholBeer() {
        #expect(DrinkMath.alcoholGrams(volumeMl: 500, abvPercent: 5).isClose(to: 19.725))
    }

    @Test("Alkohol fliesst mit 7 kcal pro Gramm in die Energie ein")
    func alcoholEnergy() {
        let totals = DrinkMath.totals(per100ml: DrinkType.wine.defaultNutrientsPer100ml, volumeMl: 100, abvPercent: 12.5)
        #expect((totals.alcohol ?? 0).isClose(to: 9.8625))
        #expect((totals.kcal ?? 0).isClose(to: 2 + 9.8625 * 7))
    }

    @Test("Alkohol zählt nicht zur Flüssigkeit, Kaffee schon")
    func fluidRules() {
        #expect(!DrinkType.beer.countsAsFluidByDefault)
        #expect(!DrinkType.wine.countsAsFluidByDefault)
        #expect(DrinkType.coffee.countsAsFluidByDefault)
        #expect(DrinkType.water.countsAsFluidByDefault)
    }

    @Test("Kaffee bringt Koffein mit")
    func caffeine() {
        let totals = DrinkMath.totals(per100ml: DrinkType.coffee.defaultNutrientsPer100ml, volumeMl: 150, abvPercent: 0)
        #expect((totals.caffeine ?? 0).isClose(to: 82.5))
        #expect(totals.alcohol == nil)
    }
}

@Suite("Mahlzeit-Kategorien")
struct MealCategoryTests {
    let calendar = TestCalendar.calendar

    @Test("Vorschlag aus der Uhrzeit", arguments: [
        (7, 0, MealCategory.breakfast),
        (9, 29, .breakfast),
        (9, 30, .morningSnack),
        (12, 15, .lunch),
        (15, 0, .afternoonSnack),
        (17, 30, .dinner),
        (21, 59, .dinner),
        (22, 0, .snack),
        (3, 0, .snack)
    ])
    func suggestion(hour: Int, minute: Int, expected: MealCategory) {
        let date = TestCalendar.date(2026, 9, 24, hour, minute)
        #expect(MealCategory.suggested(for: date, calendar: calendar) == expected)
    }
}
