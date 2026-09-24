import Foundation
import Testing
@testable import buschper

@Suite("Rezept-Entwurf")
struct RecipeDraftTests {
    @Test("Pro Portion aus den Zutaten")
    func perServing() {
        var draft = RecipeDraft()
        draft.name = "Lasagne"
        draft.servings = 4
        draft.ingredients = [
            .init(name: "Teigwaren", amountG: 250, isLiquid: false, per100: Nutrients(kcal: 355), sourceKind: .external, sourceId: nil),
            .init(name: "Hackfleisch", amountG: 400, isLiquid: false, per100: Nutrients(kcal: 230), sourceKind: .external, sourceId: nil)
        ]
        #expect(draft.isValid)
        #expect(draft.total.kcal == 887.5 + 920)
        #expect(draft.perServing.kcal == (887.5 + 920) / 4)
    }

    @Test("Ohne Zutaten oder Name nicht speicherbar")
    func invalid() {
        var draft = RecipeDraft()
        #expect(!draft.isValid)
        draft.name = "Leer"
        #expect(!draft.isValid)
    }

    @Test("Geteilte Mahlzeit als Vorlage behält die Summe")
    func fromSharedMeal() {
        let shared = SharedMeal(title: "Zmittag", category: .lunch, entries: [
            .init(name: "Pasta", amount: 200, unitLabel: "g", grams: 200, nutrients: Nutrients(kcal: 300, carbs: 60)),
            .init(name: "Kantine", amount: 1, unitLabel: "", grams: 0, nutrients: Nutrients(kcal: 500))
        ])
        let draft = RecipeDraft(sharedMeal: shared)
        #expect(draft.servings == 1)
        #expect(draft.ingredients.count == 2)
        #expect(draft.total.kcal == 800)
        #expect(draft.ingredients[0].per100.kcal == 150)
    }
}
