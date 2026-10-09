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

    @Test("Ganzes Wort vor zusammengesetztem Wort vor irgendwo")
    func ordering() {
        let names = ["Apfelstrudel", "Apfel", "Bratapfel", "Saft, Apfel"]
        let ranked = FoodSearchRanking.rank(names, query: "apfel", name: { $0 }, limit: 10)
        #expect(ranked == ["Apfel", "Saft, Apfel", "Apfelstrudel", "Bratapfel"])
    }

    @Test("Kartoffel: die Kartoffel selbst vor Püree, Klössen und Chips")
    func potatoFirst() {
        let names = [
            "Kartoffelpüree", "Kartoffelklösse", "Kartoffel, geschält, gekocht",
            "Kartoffeln, roh", "Süsskartoffel", "Kartoffelchips", "Rösti aus Kartoffeln",
        ]
        let ranked = FoodSearchRanking.rank(names, query: "kartoffel", name: { $0 }, limit: 10)
        #expect(Array(ranked.prefix(3)) == ["Kartoffeln, roh", "Kartoffel, geschält, gekocht", "Rösti aus Kartoffeln"])
        #expect(ranked.last == "Süsskartoffel")
    }

    @Test("Je näher an der Suche, desto weiter oben – die Marke zählt nicht zum Namen")
    func closestFirst() {
        let items: [(name: String, brand: String?)] = [
            ("Kartoffel, gekocht", nil), ("Kartoffel, geschält, gekocht", nil),
            ("Kartoffeln", nil), ("Kartoffel", "Migros"),
        ]
        let ranked = FoodSearchRanking.rank(items, query: "kartoffel", name: { $0.name }, brand: { $0.brand }, limit: 10)
        #expect(ranked.map { $0.name } == ["Kartoffel", "Kartoffeln", "Kartoffel, gekocht", "Kartoffel, geschält, gekocht"])
    }

    @Test("Die Marke hilft, wenn ein Suchwort nur dort steht")
    func brandFallback() {
        #expect(FoodSearchRanking.score(name: "Vollmilch", brand: "Migros", query: "milch migros") != nil)
        #expect(FoodSearchRanking.score(name: "Milch", brand: "Coop", query: "milch migros") == nil)
        let plain = FoodSearchRanking.score(name: "Milch", query: "milch") ?? 0
        let viaBrand = FoodSearchRanking.score(name: "Milch", brand: "Migros", query: "milch migros") ?? 0
        #expect(viaBrand < plain)
    }

    @Test("Tippfehler finden trotzdem, aber nach allen echten Treffern")
    func typos() {
        #expect(FoodSearchRanking.score(name: "Kartoffel, roh", query: "kartofel") != nil)
        #expect(FoodSearchRanking.score(name: "Kartoffeln, gekocht", query: "kartofe") != nil)
        #expect(FoodSearchRanking.score(name: "Tomate", query: "tomatte") != nil)
        #expect(FoodSearchRanking.score(name: "Kartoffel", query: "karotte") == nil)
        #expect(FoodSearchRanking.score(name: "Brei", query: "brot") == nil)
        #expect(FoodSearchRanking.score(name: "Eier", query: "eo") == nil)

        let ranked = FoodSearchRanking.rank(
            ["Kartoffelpüree", "Kartoffel, roh", "Kartoffelchips"], query: "kartofel", name: { $0 }, limit: 10
        )
        #expect(ranked.first == "Kartoffel, roh")
        let mixed = FoodSearchRanking.rank(["Kartoffel", "Süsskartoffel"], query: "kartoffl", name: { $0 }, limit: 10)
        #expect(mixed == ["Kartoffel"])
    }

    @Test("Abstand zwischen Wörtern")
    func editDistance() {
        #expect(FoodSearchRanking.editDistance(Array("kartofel"), Array("kartoffel"), limit: 2) == 1)
        #expect(FoodSearchRanking.editDistance(Array("karotte"), Array("kartoff"), limit: 2) == 3)
    }

    @Test("Mehrzahl und Beugung zählen als ganzes Wort, Zusammensetzungen nicht")
    func inflection() {
        #expect(FoodSearchRanking.isWord("kartoffeln", matching: "kartoffel"))
        #expect(FoodSearchRanking.isWord("eier", matching: "ei"))
        #expect(!FoodSearchRanking.isWord("eiernudeln", matching: "ei"))
        #expect(!FoodSearchRanking.isWord("kartoffelpuree", matching: "kartoffel"))
    }

    @Test("Fremd sortierte Treffer: passende nach Regel, Rest in alter Reihenfolge hinten")
    func sortForeign() {
        let names = ["Kartoffelchips Paprika", "Chips", "Kartoffeln festkochend", "Pommes"]
        let sorted = FoodSearchRanking.sort(names, query: "kartoffel", name: { $0 })
        #expect(sorted == ["Kartoffeln festkochend", "Kartoffelchips Paprika", "Chips", "Pommes"])
    }

    @Test("Beschti Träffer: über alle Quellen, nur ganze Wörter, ohne Doppel")
    func bestHits() {
        func item(_ id: String, _ name: String, brand: String? = nil) -> FoodCandidate {
            FoodCandidate(source: .catalog(id), name: name, brand: brand, barcode: nil, isLiquid: false,
                          per100: Nutrients(kcal: 80), portions: [], isFavorite: false, sourceLabel: "")
        }
        let own = [item("1", "Kartoffelstock", brand: "Mama")]
        let remembered = [item("2", "Kartoffeln festkochend", brand: "Migros")]
        let catalog = [item("3", "Kartoffelpüree"), item("4", "Kartoffeln, roh"), item("2", "Kartoffeln festkochend")]
        let best = FoodSearchService.bestHits([own, [], remembered, catalog], query: "kartoffel")
        #expect(best.map(\.id) == ["catalog-4", "catalog-2"])
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
        #expect(item.name == "Mahlzyt")
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
