import CoreData
import Foundation
import Testing
@testable import buschper

/// Gespeicherte ganze Mahlzeiten (SPEC 5.10): hin und zurück ohne Werteverlust,
/// und getrennt von den Rezepten.
@MainActor
struct MealTemplateTests {
    private func makeStore() -> DataStore {
        let defaults = UserDefaults(suiteName: "buschper-tests-\(UUID().uuidString)")!
        return DataStore(persistence: PersistenceController(role: .inMemory), preferences: AppPreferences(defaults: defaults))
    }

    private let basket: [BasketItem] = [
        BasketItem(
            name: "Müesli", count: 60, portion: PortionChoice(name: nil, gramsPerUnit: 1), isLiquid: false,
            per100: Nutrients(kcal: 380, carbs: 60, protein: 10), fixedTotal: nil, kind: .external, sourceId: "catalog:muesli"
        ),
        BasketItem(
            name: "Kafi", count: 1, portion: PortionChoice(name: "Tasse", gramsPerUnit: 200), isLiquid: true,
            per100: Nutrients(kcal: 2), fixedTotal: nil, kind: .external, sourceId: nil
        ),
        BasketItem.quick(name: "Gipfeli Kantine", carbs: 25, protein: 5, fat: 12, fiber: nil, alcohol: nil, kcalOnly: nil),
        BasketItem(
            name: "Lasagne", count: 1.5, portion: PortionChoice(name: "Portion", gramsPerUnit: 100), isLiquid: false,
            per100: Nutrients(kcal: 600, protein: 30), fixedTotal: nil, kind: .recipe, sourceId: UUID().uuidString
        ),
    ]

    @Test("Chörbli als Mahlzyt: Summe bleibt gleich")
    func roundTrip() {
        let store = makeStore()
        let template = store.saveMealTemplate(name: "  Mys Zmorge ", items: basket)
        #expect(template.displayName == "Mys Zmorge")
        #expect(template.isMealTemplate)

        let items = store.basketItems(fromTemplate: template)
        #expect(items.count == 4)
        #expect(items.map(\.name) == basket.map(\.name))
        let before = NutrientSum(basket.map(\.total)).values
        let after = NutrientSum(items.map(\.total)).values
        #expect((after.kcal ?? 0).isClose(to: before.kcal ?? 0))
        #expect((after.protein ?? 0).isClose(to: before.protein ?? 0))
        #expect(items[2].kind == .quick)
        #expect(items[3].kind == .recipe)
        #expect(items[3].count.isClose(to: 1.5))
        #expect(template.useCount == 1)
    }

    @Test("Mahlzyte erschiine nid bi de Rezept")
    func separatedFromRecipes() {
        let store = makeStore()
        var draft = RecipeDraft()
        draft.name = "Lasagne"
        draft.ingredients = [.init(name: "Teigwaren", amountG: 250, isLiquid: false, per100: Nutrients(kcal: 350), sourceKind: .external, sourceId: nil)]
        store.saveRecipe(draft)
        let template = store.saveMealTemplate(name: "Pasta Kantine", items: [basket[2]])
        _ = store.basketItems(fromTemplate: template)

        #expect(store.allRecipes().map(\.displayName) == ["Lasagne"])
        #expect(store.mealTemplates().map(\.displayName) == ["Pasta Kantine"])
        #expect(store.recentCandidates().allSatisfy { $0.name != "Pasta Kantine" })
    }
}
