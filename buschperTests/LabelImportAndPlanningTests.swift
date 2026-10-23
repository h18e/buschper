import Foundation
import Testing
@testable import buschper

@Suite("Nährwerttabelle: Mängi wähle")
struct LabelImportTests {
    let values = Nutrients(kcal: 200, carbs: 30, protein: 10)
    let fields: [Nutrients.Field] = [.kcal, .carbs, .protein]

    func label(_ basis: LabelBasis, grams: Double? = nil, count: Double = 1) -> LabelImport {
        LabelImport(values: values, fields: fields, isLiquid: false, basis: basis, grams: grams, count: count)
    }

    @Test("Pro 100 g mit Portion 80 g: Produkt bekommt Portion, Werte bleiben pro 100 g")
    func productPer100WithPortion() {
        var draft = ProductDraft()
        #expect(label(.per100, grams: 80).apply(to: &draft))
        #expect(draft.per100.kcal == 200)
        #expect(draft.portions.count == 1)
        #expect(draft.portions.first?.grams == 80)
        #expect(draft.portions.first?.name == "Portion")
    }

    @Test("Pro Stück: Werte werden auf 100 g umgerechnet, Stück wird Portionsgrösse")
    func productPerPiece() {
        var draft = ProductDraft()
        #expect(label(.piece, grams: 50).apply(to: &draft))
        #expect(draft.per100.kcal == 400)
        #expect(draft.per100.carbs == 60)
        #expect(draft.portions.first?.name == "Stück")
        #expect(draft.portions.first?.grams == 50)
    }

    @Test("Pro Portion ohne Gewicht geht beim Produkt nicht")
    func productPortionNeedsWeight() {
        var draft = ProductDraft()
        #expect(!label(.portion).apply(to: &draft))
        #expect(draft.per100.kcal == nil)
    }

    @Test("Mahlzeit: 100 g-Werte werden auf die gegessene Menge skaliert")
    func mealPer100() {
        #expect(label(.per100, grams: 80).total?.kcal?.isClose(to: 160) == true)
        #expect(label(.per100, grams: 80).total?.carbs?.isClose(to: 24) == true)
        #expect(label(.per100).total == nil)
    }

    @Test("Mahlzeit: Stück mal Anzahl, ganzi Mahlzyt wie sie ist")
    func mealPieceAndWhole() {
        #expect(label(.piece, count: 2).total?.kcal == 400)
        #expect(label(.portion, count: 1.5).total?.protein == 15)
        #expect(label(.wholeMeal).total == values)
    }
}

@Suite("Planti Iiträg")
struct PlannedTimeTests {
    let calendar = TestCalendar.calendar

    @Test("Feste Zyte pro Mahlzyt an emne spätere Tag")
    func laterDay() {
        let now = TestCalendar.date(2026, 10, 23, 10, 15)
        let tomorrow = TestCalendar.date(2026, 10, 24, 10, 15)
        let expected: [(MealCategory, Int)] = [
            (.breakfast, 7), (.morningSnack, 9), (.lunch, 12), (.afternoonSnack, 15), (.dinner, 19),
        ]
        for (category, hour) in expected {
            #expect(category.plannedTimestamp(on: tomorrow, now: now, calendar: calendar) == TestCalendar.date(2026, 10, 24, hour))
        }
        #expect(MealCategory.snack.plannedTimestamp(on: tomorrow, now: now, calendar: calendar) == nil)
    }

    @Test("Hüt nume, wenn d Zyt no vor eim isch")
    func today() {
        let now = TestCalendar.date(2026, 10, 23, 10, 15)
        #expect(MealCategory.dinner.plannedTimestamp(on: now, now: now, calendar: calendar) == TestCalendar.date(2026, 10, 23, 19))
        #expect(MealCategory.breakfast.plannedTimestamp(on: now, now: now, calendar: calendar) == nil)
        let closeToLunch = TestCalendar.date(2026, 10, 23, 11, 45)
        #expect(MealCategory.lunch.plannedTimestamp(on: closeToLunch, now: closeToLunch, calendar: calendar) == nil)
    }

    @Test("Vergangene Täg wärde nid planet")
    func pastDay() {
        let now = TestCalendar.date(2026, 10, 23, 10, 15)
        let yesterday = TestCalendar.date(2026, 10, 22, 10, 15)
        #expect(MealCategory.dinner.plannedTimestamp(on: yesterday, now: now, calendar: calendar) == nil)
    }
}
