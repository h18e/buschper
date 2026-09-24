import Foundation

/// Ein Suchtreffer – egal aus welcher Quelle (SPEC 5.4).
struct FoodCandidate: Identifiable, Hashable {
    enum Source: Hashable {
        /// Eigenes Produkt (inkl. korrigierter Kopien).
        case product(UUID)
        /// Mitgelieferte Liste: BLV oder Richtwerte.
        case catalog(String)
        /// Open Food Facts, Kennung ist der Barcode.
        case openFoodFacts(String)
        /// Rezept, geloggt in Portionen.
        case recipe(UUID)
    }

    var source: Source
    var name: String
    var brand: String?
    var barcode: String?
    var isLiquid: Bool
    /// Pro 100 g/ml – bei Rezepten pro Portion.
    var per100: Nutrients
    var portions: [PortionChoice]
    var isFavorite: Bool
    /// Kurzer Hinweis, woher die Werte stammen („Eigets Produkt“, „BLV“ …).
    var sourceLabel: String

    var id: String {
        switch source {
        case .product(let id): return "product-\(id.uuidString)"
        case .catalog(let id): return "catalog-\(id)"
        case .openFoodFacts(let code): return "off-\(code)"
        case .recipe(let id): return "recipe-\(id.uuidString)"
        }
    }

    var isRecipe: Bool {
        if case .recipe = source { return true }
        return false
    }

    var displayName: String {
        guard let brand, !brand.isEmpty else { return name }
        return "\(name) · \(brand)"
    }

    /// Vorgeschlagene Menge beim Antippen: eine Portion, sonst 100 g/ml.
    var defaultChoice: (portion: PortionChoice, count: Double) {
        if isRecipe {
            return (PortionChoice(name: "Portion", gramsPerUnit: 100), 1)
        }
        if let first = portions.first(where: { $0.name != nil }) {
            return (first, 1)
        }
        return (PortionChoice(name: nil, gramsPerUnit: 1), 100)
    }
}

/// Ein Eintrag im Chörbli, bevor die Mahlzeit gesichert wird (SPEC 5.3).
struct BasketItem: Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// Anzahl in Einheiten der gewählten Portion (bei Gramm: Gramm).
    var count: Double
    var portion: PortionChoice
    var isLiquid: Bool
    /// Pro 100 g/ml bzw. pro Portion bei Rezepten. `nil` beim Schnell-Iitrag.
    var per100: Nutrients?
    /// Feste Werte des Schnell-Iitrags.
    var fixedTotal: Nutrients?
    var kind: FoodEntryKind
    var sourceId: String?

    var grams: Double {
        guard per100 != nil else { return 0 }
        return portion.grams(for: count)
    }

    /// Gramm, die gespeichert werden. Rezepte haben kein Gewicht, nur Portionen.
    var storedGrams: Double {
        kind == .recipe ? 0 : grams
    }

    var total: Nutrients {
        if let fixedTotal { return fixedTotal }
        return per100?.forAmount(grams) ?? Nutrients()
    }

    var unitLabel: String {
        if kind == .recipe { return "Portion" }
        if kind == .quick { return "" }
        return portion.name ?? (isLiquid ? "ml" : "g")
    }

    var amountLabel: String {
        switch kind {
        case .quick:
            return "Schnäll-Iitrag"
        case .recipe:
            return "\(NumberText.amount(count)) \(count == 1 ? "Portion" : "Portione")"
        case .product, .external:
            return portion.label(count: count, isLiquid: isLiquid)
        }
    }

    static func from(_ candidate: FoodCandidate, portion: PortionChoice, count: Double) -> BasketItem {
        let kind: FoodEntryKind
        let sourceId: String
        switch candidate.source {
        case .product(let id):
            kind = .product
            sourceId = id.uuidString
        case .recipe(let id):
            kind = .recipe
            sourceId = id.uuidString
        case .catalog(let id):
            kind = .external
            sourceId = "catalog:\(id)"
        case .openFoodFacts(let code):
            kind = .external
            sourceId = "off:\(code)"
        }
        return BasketItem(
            name: candidate.displayName,
            count: count,
            portion: portion,
            isLiquid: candidate.isLiquid,
            per100: candidate.per100,
            fixedTotal: nil,
            kind: kind,
            sourceId: sourceId
        )
    }

    /// Schnell-Iitrag (SPEC 5.6): Makros → kcal, oder nur kcal.
    static func quick(name: String, carbs: Double?, protein: Double?, fat: Double?, fiber: Double?, alcohol: Double?, kcalOnly: Double?) -> BasketItem {
        var total = Nutrients()
        if let kcalOnly {
            total.kcal = kcalOnly
        } else {
            total.carbs = carbs
            total.protein = protein
            total.fat = fat
            total.fiber = fiber
            total.alcohol = alcohol
            total.kcal = Nutrients.kcal(carbs: carbs, protein: protein, fat: fat, alcohol: alcohol)
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return BasketItem(
            name: trimmed.isEmpty ? "Schnäll-Iitrag" : trimmed,
            count: 1,
            portion: PortionChoice(name: nil, gramsPerUnit: 1),
            isLiquid: false,
            per100: nil,
            fixedTotal: total,
            kind: .quick,
            sourceId: nil
        )
    }
}

/// Rangfolge der Suchtreffer innerhalb einer Quelle.
enum FoodSearchRanking {
    /// Kleinschreibung, ohne Akzente: „Rüebli“ findet „ruebli“ und „Ruebli“,
    /// „Gruyère“ findet „gruyere“.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "de_CH"))
            .lowercased()
    }

    /// Punktzahl eines Namens für eine Suche, `nil` wenn er nicht passt.
    /// Alle Suchwörter müssen vorkommen. Besser ist: Name beginnt mit der Suche,
    /// dann ein Wort beginnt damit, dann irgendwo enthalten; kürzere Namen zuerst.
    static func score(name: String, query: String) -> Int? {
        let haystack = normalize(name)
        let needle = normalize(query).trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return nil }
        let words = needle.split(separator: " ").map(String.init)
        guard words.allSatisfy({ haystack.contains($0) }) else { return nil }

        var score = 1000
        if haystack.hasPrefix(needle) {
            score += 500
        } else if haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                    .contains(where: { $0.hasPrefix(words[0]) }) {
            score += 250
        }
        if haystack == needle { score += 300 }
        score -= min(200, haystack.count)
        return score
    }

    static func rank<T>(_ items: [T], query: String, name: (T) -> String, limit: Int) -> [T] {
        items
            .compactMap { item in score(name: name(item), query: query).map { (item, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}
