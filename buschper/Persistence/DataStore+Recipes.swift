import CoreData
import Foundation

/// Entwurf eines Rezepts (SPEC 5.7).
struct RecipeDraft: Equatable {
    struct Ingredient: Equatable, Identifiable {
        var id = UUID()
        var name: String
        var amountG: Double
        var isLiquid: Bool
        var per100: Nutrients
        var sourceKind: FoodEntryKind
        var sourceId: String?

        var total: Nutrients { per100.forAmount(amountG) }
    }

    var name = ""
    var servings: Double = 4
    var note = ""
    var ingredients: [Ingredient] = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && servings > 0 && !ingredients.isEmpty
    }

    var total: Nutrients {
        RecipeMath.total(ingredients.map { IngredientAmount(amountG: $0.amountG, per100: $0.per100) })
    }

    var perServing: Nutrients {
        RecipeMath.perServing(total: total, servings: servings)
    }

    init() {}

    init(recipe: Recipe) {
        name = recipe.name ?? ""
        servings = recipe.servings
        note = recipe.note ?? ""
        ingredients = recipe.ingredientList.map { item in
            Ingredient(
                name: item.name ?? "",
                amountG: item.amountG,
                isLiquid: item.isLiquid,
                per100: item.per100,
                sourceKind: FoodEntryKind(rawValue: item.sourceKindRaw ?? "") ?? .external,
                sourceId: item.sourceId
            )
        }
    }

    /// Eine geteilte Mahlzeit als Vorlage: jede Zutat mit ihrem Gewicht, eine Portion.
    /// Einträge ohne Gewicht (Schnell-Iitrag, Rezeptportionen) werden als 100 g
    /// mit ihren Gesamtwerten übernommen, damit die Summe stimmt.
    init(sharedMeal: SharedMeal) {
        name = sharedMeal.title
        servings = 1
        ingredients = sharedMeal.entries.map { entry in
            let grams = entry.grams > 0 ? entry.grams : 100
            return Ingredient(
                name: entry.name,
                amountG: grams,
                isLiquid: entry.unitLabel == "ml",
                per100: entry.nutrients.scaled(by: 100 / grams),
                sourceKind: .external,
                sourceId: nil
            )
        }
    }
}

extension DataStore {

    // MARK: - Rezepte

    func allRecipes() -> [Recipe] {
        fetch(Recipe.self, sort: [NSSortDescriptor(key: "name", ascending: true)])
    }

    @discardableResult
    func saveRecipe(_ draft: RecipeDraft, editing existing: Recipe? = nil) -> Recipe {
        let recipe = existing ?? {
            let recipe = Recipe(context: context)
            recipe.id = UUID()
            recipe.createdAt = Date()
            return recipe
        }()
        recipe.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.servings = max(0.25, draft.servings)
        recipe.note = draft.note
        recipe.updatedAt = Date()

        recipe.ingredientList.forEach(context.delete)
        for (index, ingredient) in draft.ingredients.enumerated() {
            let item = RecipeIngredient(context: context)
            item.id = UUID()
            item.name = ingredient.name
            item.amountG = ingredient.amountG
            item.isLiquid = ingredient.isLiquid
            item.per100 = ingredient.per100
            item.sourceKindRaw = ingredient.sourceKind.rawValue
            item.sourceId = ingredient.sourceId ?? ""
            item.sortIndex = Int32(index)
            item.recipe = recipe
        }
        save()
        return recipe
    }

    func deleteRecipe(_ recipe: Recipe) {
        context.delete(recipe)
        save()
    }

    // MARK: - Einträge zurück ins Chörbli

    /// Ein gespeicherter Eintrag als Chörbli-Eintrag – fürs Kopieren und „Wie geschter“.
    func basketItem(from entry: FoodEntry) -> BasketItem {
        switch entry.kind {
        case .quick:
            return BasketItem(
                name: entry.displayName, count: 1, portion: PortionChoice(name: nil, gramsPerUnit: 1),
                isLiquid: false, per100: nil, fixedTotal: entry.total, kind: .quick, sourceId: nil
            )
        case .recipe:
            let servings = max(entry.servings, 0.25)
            return BasketItem(
                name: entry.displayName, count: servings, portion: PortionChoice(name: "Portion", gramsPerUnit: 100),
                isLiquid: false, per100: entry.total.scaled(by: 1 / servings), fixedTotal: nil,
                kind: .recipe, sourceId: entry.sourceId
            )
        case .product, .external:
            let grams = entry.grams
            guard grams > 0 else {
                return BasketItem(
                    name: entry.displayName, count: 1, portion: PortionChoice(name: nil, gramsPerUnit: 1),
                    isLiquid: entry.isLiquid, per100: nil, fixedTotal: entry.total, kind: .quick, sourceId: nil
                )
            }
            let unit = entry.isLiquid ? "ml" : "g"
            let isPortion = (entry.unitLabel ?? unit) != unit && entry.amount > 0
            let portion = isPortion
                ? PortionChoice(name: entry.unitLabel, gramsPerUnit: grams / entry.amount)
                : PortionChoice(name: nil, gramsPerUnit: 1)
            return BasketItem(
                name: entry.displayName, count: isPortion ? entry.amount : grams, portion: portion,
                isLiquid: entry.isLiquid, per100: entry.total.scaled(by: 100 / grams), fixedTotal: nil,
                kind: entry.kind, sourceId: entry.sourceId
            )
        }
    }

    /// Mahlzeiten einer Kategorie an einem Tag – für „Wie geschter“.
    func entries(category: MealCategory, on day: Date) -> [FoodEntry] {
        meals(on: day).filter { $0.category == category }.flatMap(\.entryList)
    }

    // MARK: - Kopieren (Q15)

    @discardableResult
    func copy(entries: [FoodEntry], to timestamp: Date, category: MealCategory, title: String?) -> Meal? {
        let items = entries.map(basketItem(from:))
        return saveMeal(items: items, timestamp: timestamp, category: category, title: title)
    }

    // MARK: - Teilen (SPEC 6)

    func sharedMeal(from meal: Meal) -> SharedMeal {
        SharedMeal(
            title: meal.displayTitle,
            category: meal.category,
            entries: meal.entryList.map { entry in
                SharedMeal.Entry(
                    name: entry.displayName,
                    amount: entry.kind == .recipe ? entry.servings : entry.amount,
                    unitLabel: entry.unitLabel ?? "",
                    grams: entry.grams,
                    nutrients: entry.total
                )
            }
        )
    }

    /// Geteilte Mahlzeit in den eigenen Tag übernehmen.
    @discardableResult
    func importMeal(_ shared: SharedMeal, at timestamp: Date, category: MealCategory) -> Meal? {
        let items = shared.entries.map { entry -> BasketItem in
            if entry.grams > 0 {
                let unit = entry.unitLabel == "ml" ? "ml" : "g"
                let isPortion = !entry.unitLabel.isEmpty && entry.unitLabel != unit && entry.amount > 0
                return BasketItem(
                    name: entry.name,
                    count: isPortion ? entry.amount : entry.grams,
                    portion: isPortion ? PortionChoice(name: entry.unitLabel, gramsPerUnit: entry.grams / entry.amount)
                                       : PortionChoice(name: nil, gramsPerUnit: 1),
                    isLiquid: unit == "ml",
                    per100: entry.nutrients.scaled(by: 100 / entry.grams),
                    fixedTotal: nil,
                    kind: .external,
                    sourceId: nil
                )
            }
            return BasketItem(
                name: entry.name, count: 1, portion: PortionChoice(name: nil, gramsPerUnit: 1),
                isLiquid: false, per100: nil, fixedTotal: entry.nutrients, kind: .quick, sourceId: nil
            )
        }
        return saveMeal(items: items, timestamp: timestamp, category: category, title: shared.title)
    }
}
