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
        servings = sharedMeal.servings ?? 1
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

    /// Nur echte Rezepte, ohne gespeicherte Mahlzeiten.
    func allRecipes() -> [Recipe] {
        fetch(Recipe.self, predicate: RecipeKind.recipesOnly, sort: [NSSortDescriptor(key: "name", ascending: true)])
    }

    @discardableResult
    func saveRecipe(_ draft: RecipeDraft, editing existing: Recipe? = nil) -> Recipe {
        let recipe = existing ?? {
            let recipe = Recipe(context: context)
            recipe.id = UUID()
            recipe.createdAt = Date()
            recipe.kind = .recipe
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

    // MARK: - Gespeicherte Mahlzeiten (SPEC 5.10)

    /// Zuletzt verwendete zuerst, dann nach Name.
    func mealTemplates() -> [Recipe] {
        fetch(Recipe.self, predicate: RecipeKind.mealsOnly, sort: [
            NSSortDescriptor(key: "lastUsedAt", ascending: false),
            NSSortDescriptor(key: "name", ascending: true),
        ])
    }

    /// Speichert Chörbli-Einträge als ganze Mahlzeit.
    ///
    /// Jeder Eintrag wird eine Zutat mit Gramm und Werten pro 100 g – bei Rezepten
    /// wie im Chörbli: 100 „Gramm“ je Portion, Werte pro Portion. Einträge mit
    /// festen Werten (Ganzi Mahlzyt, Schnäll-Iitrag) werden als 100 g mit ihren
    /// Gesamtwerten abgelegt, damit die Summe stimmt.
    @discardableResult
    func saveMealTemplate(name: String, items: [BasketItem]) -> Recipe {
        let template = Recipe(context: context)
        template.id = UUID()
        template.createdAt = Date()
        template.updatedAt = Date()
        template.kind = .meal
        template.servings = 1
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        template.name = trimmed.isEmpty ? (items.first?.name ?? "Mahlzyt") : trimmed

        for (index, basketItem) in items.enumerated() {
            let item = RecipeIngredient(context: context)
            item.id = UUID()
            item.name = basketItem.name
            item.isLiquid = basketItem.isLiquid
            item.sortIndex = Int32(index)
            if let per100 = basketItem.per100, basketItem.fixedTotal == nil, basketItem.grams > 0 {
                item.amountG = basketItem.grams
                item.per100 = per100
                item.sourceKindRaw = basketItem.kind.rawValue
                item.sourceId = basketItem.sourceId ?? ""
            } else {
                item.amountG = 100
                item.per100 = basketItem.total
                item.sourceKindRaw = FoodEntryKind.quick.rawValue
                item.sourceId = ""
            }
            item.recipe = template
        }
        save()
        return template
    }

    /// Die Einträge einer gespeicherten Mahlzeit fürs Chörbli. Vermerkt die Nutzung.
    func basketItems(fromTemplate template: Recipe) -> [BasketItem] {
        template.markUsed()
        save()
        return template.ingredientList.map { item in
            let name = item.name ?? ""
            let kind = FoodEntryKind(rawValue: item.sourceKindRaw ?? "") ?? .external
            let sourceId = (item.sourceId ?? "").isEmpty ? nil : item.sourceId
            switch kind {
            case .quick:
                return BasketItem(
                    name: name, count: 1, portion: PortionChoice(name: nil, gramsPerUnit: 1),
                    isLiquid: item.isLiquid, per100: nil, fixedTotal: item.per100.forAmount(item.amountG),
                    kind: .quick, sourceId: nil
                )
            case .recipe:
                return BasketItem(
                    name: name, count: item.amountG / 100, portion: PortionChoice(name: "Portion", gramsPerUnit: 100),
                    isLiquid: false, per100: item.per100, fixedTotal: nil, kind: .recipe, sourceId: sourceId
                )
            case .product, .external:
                return BasketItem(
                    name: name, count: item.amountG, portion: PortionChoice(name: nil, gramsPerUnit: 1),
                    isLiquid: item.isLiquid, per100: item.per100, fixedTotal: nil, kind: kind, sourceId: sourceId
                )
            }
        }
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

    /// Ein Rezept zum Teilen: alle Zutaten mit Menge und Nährwerten, dazu die Portionen.
    func sharedRecipe(from recipe: Recipe) -> SharedMeal {
        SharedMeal(
            title: recipe.displayName,
            category: .dinner,
            entries: recipe.ingredientList.map { item in
                SharedMeal.Entry(
                    name: item.name ?? "",
                    amount: item.amountG,
                    unitLabel: item.isLiquid ? "ml" : "g",
                    grams: item.amountG,
                    nutrients: item.per100.forAmount(item.amountG)
                )
            },
            servings: recipe.servings
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
