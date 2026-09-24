import Foundation
import Testing
@testable import buschper

@Suite("Nährwerte")
struct NutrientsTests {
    @Test("Pro 100 g auf eine Menge umrechnen")
    func forAmount() {
        let per100 = Nutrients(kcal: 200, carbs: 30, protein: 10)
        let portion = per100.forAmount(150)
        #expect(portion.kcal == 300)
        #expect(portion.carbs == 45)
        #expect(portion.protein == 15)
        #expect(portion.fat == nil)
    }

    @Test("Unbekannt bleibt beim Skalieren unbekannt")
    func scalingKeepsUnknown() {
        let scaled = Nutrients(kcal: 100).scaled(by: 2)
        #expect(scaled.fiber == nil)
        #expect(scaled.kcal == 200)
    }

    @Test("Summe: bekannt plus unbekannt ergibt den bekannten Wert")
    func sumMixed() {
        let sum = Nutrients(kcal: 100, fiber: 3) + Nutrients(kcal: 50)
        #expect(sum.kcal == 150)
        #expect(sum.fiber == 3)
        #expect(sum.fat == nil)
    }

    @Test("Summe merkt sich, wo Angaben gefehlt haben")
    func incompleteFields() {
        let sum = NutrientSum([Nutrients(kcal: 100, fiber: 3), Nutrients(kcal: 50)])
        #expect(sum.kcal == 150)
        #expect(sum.incompleteFields == [.fiber])
        #expect(sum.entryCount == 2)
    }

    @Test("Kennt niemand einen Wert, ist er unbekannt, nicht unvollständig")
    func unknownIsNotIncomplete() {
        let sum = NutrientSum([Nutrients(kcal: 100), Nutrients(kcal: 50)])
        #expect(sum.values.fiber == nil)
        #expect(!sum.incompleteFields.contains(.fiber))
    }

    @Test("Zwei Summen zusammenzählen erkennt Lücken über die Grenze")
    func addingSums() {
        let first = NutrientSum([Nutrients(kcal: 100, fiber: 2)])
        let second = NutrientSum([Nutrients(kcal: 50)])
        let total = first + second
        #expect(total.kcal == 150)
        #expect(total.incompleteFields.contains(.fiber))
        #expect(total.entryCount == 2)
    }

    @Test("Energie aus Makros: 4 / 4 / 9 / 7 kcal pro Gramm")
    func kcalFromMacros() {
        #expect(Nutrients.kcal(carbs: 50, protein: 20, fat: 10) == 370)
        #expect(Nutrients.kcal(carbs: nil, protein: nil, fat: nil, alcohol: 10) == 70)
    }

    @Test("JSON hin und zurück")
    func jsonRoundTrip() {
        let original = Nutrients(kcal: 120, carbs: 12.5, salt: 0.3, caffeine: 40)
        let restored = Nutrients(jsonString: original.jsonString)
        #expect(restored == original)
    }

    @Test("Leeres oder kaputtes JSON ergibt leere Werte statt Absturz")
    func brokenJSON() {
        #expect(Nutrients(jsonString: nil).isEmpty)
        #expect(Nutrients(jsonString: "").isEmpty)
        #expect(Nutrients(jsonString: "kein json").isEmpty)
    }
}
