import Foundation
import Testing
@testable import buschper

@Suite("Lebensmittelsuche")
struct FoodSearchTests {
    @Test("Umlaute und Akzente spielen keine Rolle")
    func diacritics() {
        #expect(FoodSearchRanking.score(name: "Rüebli (Karotte)", query: "ruebli") != nil)
        #expect(FoodSearchRanking.score(name: "Rüebli (Karotte)", query: "rüebli") != nil)
        #expect(FoodSearchRanking.score(name: "Rüebli (Karotte)", query: "gurke") == nil)
        #expect(FoodSearchRanking.score(name: "Gruyère", query: "gruyere") != nil)
        #expect(FoodSearchRanking.score(name: "Apfel", query: "APF") != nil)
    }

    @Test("Alle Suchwörter müssen vorkommen")
    func allWords() {
        #expect(FoodSearchRanking.score(name: "Pouletbrust, gebraten", query: "poulet gebr") != nil)
        #expect(FoodSearchRanking.score(name: "Pouletbrust, roh", query: "poulet gebr") == nil)
    }

    @Test("Anfang vor Wortanfang vor irgendwo, kürzer vor länger")
    func ordering() {
        let names = ["Apfelstrudel", "Apfel", "Bratapfel", "Saft, Apfel"]
        let ranked = FoodSearchRanking.rank(names, query: "apfel", name: { $0 }, limit: 10)
        #expect(ranked == ["Apfel", "Apfelstrudel", "Saft, Apfel", "Bratapfel"])
    }
}

@Suite("Chörbli")
struct BasketTests {
    let candidate = FoodCandidate(
        source: .catalog("basic-brot"), name: "Ruchbrot", brand: nil, barcode: nil, isLiquid: false,
        per100: Nutrients(kcal: 240, carbs: 45, protein: 8.5),
        portions: [PortionChoice(name: nil, gramsPerUnit: 1), PortionChoice(name: "Schiibe", gramsPerUnit: 40)],
        isFavorite: false, sourceLabel: "Richtwärt"
    )

    @Test("Vorgeschlagene Menge ist die erste eigene Portion")
    func defaultChoice() {
        let choice = candidate.defaultChoice
        #expect(choice.portion.name == "Schiibe")
        #expect(choice.count == 1)
    }

    @Test("Zwei Scheiben Brot")
    func twoSlices() {
        let item = BasketItem.from(candidate, portion: PortionChoice(name: "Schiibe", gramsPerUnit: 40), count: 2)
        #expect(item.grams == 80)
        #expect(item.total.kcal == 192)
        #expect(item.kind == .external)
        #expect(item.sourceId == "catalog:basic-brot")
        #expect(item.amountLabel == "2 × Schiibe (80 g)")
    }

    @Test("Schnell-Iitrag rechnet kcal aus Makros")
    func quickMacros() {
        let item = BasketItem.quick(name: "Pasta Kantine", carbs: 90, protein: 25, fat: 20, fiber: 5, alcohol: nil, kcalOnly: nil)
        #expect(item.total.kcal == 640)
        #expect(item.total.fiber == 5)
        #expect(item.storedGrams == 0)
        #expect(item.kind == .quick)
    }

    @Test("Schnell-Iitrag nur mit kcal lässt die Makros leer")
    func quickKcalOnly() {
        let item = BasketItem.quick(name: "", carbs: nil, protein: nil, fat: nil, fiber: nil, alcohol: nil, kcalOnly: 750)
        #expect(item.total.kcal == 750)
        #expect(item.total.carbs == nil)
        #expect(item.name == "Schnäll-Iitrag")
    }

    @Test("Rezept in Portionen: Werte pro Portion mal Anzahl, ohne Gewicht")
    func recipe() {
        let recipe = FoodCandidate(
            source: .recipe(UUID()), name: "Lasagne", brand: nil, barcode: nil, isLiquid: false,
            per100: Nutrients(kcal: 600, protein: 30), portions: [], isFavorite: false, sourceLabel: "Rezept"
        )
        let choice = recipe.defaultChoice
        let item = BasketItem.from(recipe, portion: choice.portion, count: 1.5)
        #expect(item.total.kcal == 900)
        #expect(item.storedGrams == 0)
        #expect(item.amountLabel == "1.5 Portione")
    }
}
