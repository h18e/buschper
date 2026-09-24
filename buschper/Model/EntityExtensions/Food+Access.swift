import CoreData
import Foundation

/// Woher ein eigenes Produkt stammt.
enum ProductOrigin: String, Codable {
    /// Selbst erfasst.
    case own
    /// Korrigierte Kopie eines Open-Food-Facts-Produkts.
    case offCopy
    /// Korrigierte Kopie eines BLV-Eintrags.
    case blvCopy
}

/// Quelle eines fremden Produkts.
enum ExternalFoodSource: String, Codable {
    case off
    case blv

    var label: String {
        switch self {
        case .off: return "Open Food Facts"
        case .blv: return "Schwiizer Nährwärtdatebank"
        }
    }
}

/// Art eines geloggten Eintrags.
enum FoodEntryKind: String, Codable {
    case product
    case external
    case recipe
    case quick
}

extension FoodProduct {
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohni Name" : trimmed
    }

    var per100: Nutrients {
        get { Nutrients(jsonString: nutrientsJSON) }
        set { nutrientsJSON = newValue.jsonString }
    }

    var origin: ProductOrigin {
        get { ProductOrigin(rawValue: originRaw ?? "") ?? .own }
        set { originRaw = newValue.rawValue }
    }

    var barcodeText: String? {
        guard let barcode, !barcode.isEmpty else { return nil }
        return barcode
    }

    var portionList: [PortionSize] {
        let all = (portions as? Set<PortionSize>).map(Array.init) ?? []
        return all.sorted { $0.sortIndex < $1.sortIndex }
    }

    var portionChoices: [PortionChoice] {
        [PortionChoice(name: nil, gramsPerUnit: 1)]
            + portionList.filter { $0.grams > 0 }.map { PortionChoice(name: $0.name, gramsPerUnit: $0.grams) }
    }

    func markUsed(at date: Date = Date()) {
        useCount += 1
        lastUsedAt = date
    }
}

extension ExternalFoodRef {
    var per100: Nutrients {
        get { Nutrients(jsonString: nutrientsJSON) }
        set { nutrientsJSON = newValue.jsonString }
    }

    var source: ExternalFoodSource {
        get { ExternalFoodSource(rawValue: sourceRaw ?? "") ?? .off }
        set { sourceRaw = newValue.rawValue }
    }

    func markUsed(at date: Date = Date()) {
        useCount += 1
        lastUsedAt = date
    }
}

extension Recipe {
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Rezept ohni Name" : trimmed
    }

    var ingredientList: [RecipeIngredient] {
        let all = (ingredients as? Set<RecipeIngredient>).map(Array.init) ?? []
        return all.sorted { $0.sortIndex < $1.sortIndex }
    }

    var ingredientAmounts: [IngredientAmount] {
        ingredientList.map { IngredientAmount(amountG: $0.amountG, per100: $0.per100) }
    }

    var totalNutrients: Nutrients { RecipeMath.total(ingredientAmounts) }

    var perServing: Nutrients {
        RecipeMath.perServing(total: totalNutrients, servings: servings)
    }

    func markUsed(at date: Date = Date()) {
        useCount += 1
        lastUsedAt = date
    }
}

extension RecipeIngredient {
    var per100: Nutrients {
        get { Nutrients(jsonString: nutrientsJSON) }
        set { nutrientsJSON = newValue.jsonString }
    }
}

extension Meal {
    var category: MealCategory {
        get { MealCategory(rawValue: categoryRaw ?? "") ?? .snack }
        set { categoryRaw = newValue.rawValue }
    }

    var entryList: [FoodEntry] {
        let all = (entries as? Set<FoodEntry>).map(Array.init) ?? []
        return all.sorted { $0.sortIndex < $1.sortIndex }
    }

    var nutrientSum: NutrientSum {
        NutrientSum(entryList.map(\.total))
    }

    var displayTitle: String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? category.label : trimmed
    }
}

extension FoodEntry {
    var total: Nutrients {
        get { Nutrients(jsonString: nutrientsJSON) }
        set { nutrientsJSON = newValue.jsonString }
    }

    var kind: FoodEntryKind {
        get { FoodEntryKind(rawValue: kindRaw ?? "") ?? .product }
        set { kindRaw = newValue.rawValue }
    }

    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohni Name" : trimmed
    }
}

extension DrinkEntry {
    var drinkType: DrinkType {
        get { DrinkType(rawValue: drinkTypeRaw ?? "") ?? .water }
        set { drinkTypeRaw = newValue.rawValue }
    }

    var total: Nutrients {
        get { Nutrients(jsonString: nutrientsJSON) }
        set { nutrientsJSON = newValue.jsonString }
    }

    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? drinkType.label : trimmed
    }

    /// Menge, die zum Flüssigkeitsziel zählt.
    var fluidMl: Double { countsAsFluid ? volumeMl : 0 }
}

extension DrinkPreset {
    var drinkType: DrinkType {
        get { DrinkType(rawValue: drinkTypeRaw ?? "") ?? .custom }
        set { drinkTypeRaw = newValue.rawValue }
    }

    var per100: Nutrients {
        get { Nutrients(jsonString: nutrientsJSON) }
        set { nutrientsJSON = newValue.jsonString }
    }
}
