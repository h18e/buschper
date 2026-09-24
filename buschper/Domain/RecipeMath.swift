import Foundation

/// Eine Zutat mit Menge und Nährwerten pro 100 g/ml.
struct IngredientAmount: Equatable {
    var amountG: Double
    var per100: Nutrients
}

/// Rezept-Nährwerte (SPEC 5.7).
enum RecipeMath {
    /// Kleinster Schritt beim Loggen: eine Viertelportion.
    static let servingStep = 0.25

    static func total(_ ingredients: [IngredientAmount]) -> Nutrients {
        NutrientSum(ingredients.map { $0.per100.forAmount($0.amountG) }).values
    }

    static func totalWeight(_ ingredients: [IngredientAmount]) -> Double {
        ingredients.reduce(0) { $0 + max(0, $1.amountG) }
    }

    static func perServing(total: Nutrients, servings: Double) -> Nutrients {
        guard servings > 0 else { return total }
        return total.scaled(by: 1 / servings)
    }

    /// Nährwerte für `servings` Portionen eines Rezepts mit `recipeServings` Portionen.
    static func forServings(_ servings: Double, of ingredients: [IngredientAmount], recipeServings: Double) -> Nutrients {
        perServing(total: total(ingredients), servings: recipeServings).scaled(by: servings)
    }

    /// Auf Viertelportionen runden, nie unter einer Viertelportion.
    static func roundedServings(_ value: Double) -> Double {
        max(servingStep, (value / servingStep).rounded() * servingStep)
    }
}

/// Mengenangabe beim Loggen: Gramm/Milliliter direkt oder eine Portionsgrösse.
struct PortionChoice: Equatable, Hashable {
    /// z. B. „1 Schiibe“. `nil` heisst: Gramm bzw. ml.
    var name: String?
    /// Gramm pro Portion, bei `name == nil` immer 1.
    var gramsPerUnit: Double

    static func grams(isLiquid: Bool) -> PortionChoice {
        PortionChoice(name: nil, gramsPerUnit: 1)
    }

    func grams(for count: Double) -> Double {
        max(0, count) * gramsPerUnit
    }

    /// Beschriftung für die Liste, z. B. „2 × Schiibe (60 g)“ oder „150 g“.
    func label(count: Double, isLiquid: Bool) -> String {
        let unit = isLiquid ? "ml" : "g"
        let total = grams(for: count)
        guard let name else {
            return "\(NumberText.amount(total)) \(unit)"
        }
        return "\(NumberText.amount(count)) × \(name) (\(NumberText.amount(total)) \(unit))"
    }
}

/// Zahlen für die Anzeige, einheitlich im ganzen Programm.
enum NumberText {
    /// Ganze Zahlen ohne Nachkommastellen, sonst höchstens zwei.
    static func amount(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(Int(value.rounded()))
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Ganze kcal, mit Apostroph als Tausendertrennzeichen wie in der Schweiz.
    static func kcal(_ value: Double) -> String {
        grouped(value.rounded())
    }

    static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    static func oneDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    /// Flüssigkeit: bis 1 l in ml, darüber in Litern mit einer Stelle.
    static func volume(_ ml: Double) -> String {
        if ml >= 1000 {
            return "\(oneDecimal(ml / 1000)) l"
        }
        return "\(Int(ml.rounded())) ml"
    }
}
