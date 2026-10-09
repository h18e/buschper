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
            return "Ganzi Mahlzyt"
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
            name: trimmed.isEmpty ? "Mahlzyt" : trimmed,
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

    /// Ab dieser Punktzahl ist das Suchwort ein ganzes Wort im Namen – ein
    /// Kandidat für „Beschti Träffer“.
    static let wholeWordScore = 1500

    /// Punktzahl eines Treffers, `nil` wenn er nicht passt. Je näher der Name an
    /// der Suche, desto höher.
    ///
    /// Bewertet wird der **Name ohne Marke** – „Kartoffel“ von Migros ist für die
    /// Suche „kartoffel“ ein genauer Treffer. Die Marke hilft nur, wenn ein
    /// Suchwort im Namen fehlt („kartoffel migros“); dann gibt es etwas Abzug.
    static func score(name: String, brand: String? = nil, query: String) -> Int? {
        if let score = nameScore(name, query: query) { return score }
        guard let brand, !brand.trimmingCharacters(in: .whitespaces).isEmpty,
              let withBrand = nameScore("\(name) \(brand)", query: query)
        else { return nil }
        return withBrand - 200
    }

    /// Alle Suchwörter müssen vorkommen. Dann zählt, **wie nahe** der Name an
    /// der Suche ist (Stufen, von gut nach schlecht):
    ///
    /// 1. Name gleich der Suche („Kartoffel“)
    /// 2. gleich bis auf Mehrzahl oder Beugung („Kartoffeln“)
    /// 3. erstes Wort ist das Suchwort, dazu weitere Wörter („Kartoffel, gekocht“)
    /// 4. ein anderes ganzes Wort („Rösti aus Kartoffeln“)
    /// 5. Anfang eines zusammengesetzten ersten Worts („Kartoffelpüree“)
    /// 6. Anfang eines anderen Worts
    /// 7. irgendwo mitten im Wort („Süsskartoffel“)
    ///
    /// Innerhalb einer Stufe: weitere Suchwörter als ganzes Wort zählen mehr, und
    /// je weniger zusätzliche Wörter, desto besser – „Kartoffel, gekocht“ vor
    /// „Kartoffel, geschält, gekocht“.
    private static func nameScore(_ name: String, query: String) -> Int? {
        let haystack = normalize(name).trimmingCharacters(in: .whitespaces)
        let needle = normalize(query).trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return nil }
        let words = needle.split(separator: " ").map(String.init)
        let tokens = haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)

        guard words.allSatisfy({ haystack.contains($0) }) else {
            // Tippfehler: Jedes Wort steht drin oder ist einem Wort des Namens sehr
            // ähnlich („kartofel“ → „Kartoffel“). Solche Treffer kommen nach allen
            // echten Treffern.
            var wholeWords = true
            for word in words where !haystack.contains(word) {
                guard let match = typoMatch(word, of: tokens) else { return nil }
                if match == .start { wholeWords = false }
            }
            // Ganzes Wort mit Tippfehler („Kartoffel, roh“) vor ähnlichem Wortanfang
            // („Kartoffelpüree“).
            return (wholeWords ? 450 : 300) - min(300, max(0, tokens.count - words.count) * 60 + haystack.count)
        }

        let first = words[0]
        let sameWords = tokens.count == words.count
            && zip(tokens, words).allSatisfy { isWord($0, matching: $1) }
        var score: Int
        if haystack == needle || tokens == words {
            score = 3000
        } else if sameWords {
            score = 2900
        } else if let leading = tokens.first, isWord(leading, matching: first) {
            score = 2000
        } else if tokens.contains(where: { isWord($0, matching: first) }) {
            score = wholeWordScore
        } else if tokens.first?.hasPrefix(first) == true {
            score = 1000
        } else if tokens.contains(where: { $0.hasPrefix(first) }) {
            score = 800
        } else {
            score = 500
        }
        score += words.dropFirst().filter { word in tokens.contains { isWord($0, matching: word) } }.count * 100
        let extraWords = max(0, tokens.count - words.count)
        score -= min(400, extraWords * 60 + haystack.count)
        return score
    }

    /// Wie viele Tippfehler ein Wort haben darf: kurze keine, ab 4 Buchstaben
    /// einen, ab 7 Buchstaben zwei.
    static func allowedTypos(for word: String) -> Int {
        switch word.count {
        case ..<4: return 0
        case 4..<7: return 1
        default: return 2
        }
    }

    enum TypoMatch {
        /// Einem ganzen Wort des Namens ähnlich („kartofel“ – „Kartoffel“).
        case word
        /// Nur dem Anfang eines Worts ähnlich („kartofel“ – „Kartoffelpüree“).
        case start
    }

    /// Das Suchwort ist einem Wort des Namens oder dessen Anfang sehr ähnlich –
    /// so findet auch ein halb und falsch getipptes Wort („kartofe“) etwas.
    static func typoMatch(_ word: String, of tokens: [String]) -> TypoMatch? {
        let allowed = allowedTypos(for: word)
        guard allowed > 0 else { return nil }
        let target = Array(word)
        var best: TypoMatch?
        for token in tokens {
            let letters = Array(token)
            guard letters.count >= target.count - allowed else { continue }
            if editDistance(target, letters, limit: allowed) <= allowed { return .word }
            // Anfang des Worts in ähnlicher Länge vergleichen.
            let starts = (-1...1).map { target.count + $0 }.filter { $0 > 0 && $0 < letters.count }
            if starts.contains(where: { editDistance(target, Array(letters.prefix($0)), limit: allowed) <= allowed }) {
                best = .start
            }
        }
        return best
    }

    /// Levenshtein-Abstand; bricht ab, sobald `limit` sicher überschritten ist.
    static func editDistance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for (i, charA) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            var rowMinimum = current[0]
            for (j, charB) in b.enumerated() {
                current[j + 1] = Swift.min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + (charA == charB ? 0 : 1)
                )
                rowMinimum = Swift.min(rowMinimum, current[j + 1])
            }
            if rowMinimum > limit { return limit + 1 }
            previous = current
        }
        return previous[b.count]
    }

    /// Ein Wort des Namens ist das Suchwort – auch in Mehrzahl oder gebeugt
    /// („kartoffeln“, „eier“, „aepfel“ → durch die Normalisierung „apfel“).
    static func isWord(_ token: String, matching word: String) -> Bool {
        guard token.hasPrefix(word) else { return false }
        let rest = token.dropFirst(word.count)
        return ["", "n", "e", "s", "en", "er", "es", "ern", "nen"].contains(String(rest))
    }

    /// Fremd sortierte Treffer (z. B. von Open Food Facts) nach derselben Regel
    /// ordnen. Was nicht passt, bleibt in der bisherigen Reihenfolge hinten.
    static func sort<T>(_ items: [T], query: String, name: (T) -> String, brand: (T) -> String? = { _ in nil }) -> [T] {
        items.enumerated()
            .map { entry in
                (index: entry.offset, item: entry.element,
                 points: score(name: name(entry.element), brand: brand(entry.element), query: query) ?? Int.min)
            }
            .sorted { $0.points != $1.points ? $0.points > $1.points : $0.index < $1.index }
            .map(\.item)
    }

    static func rank<T>(_ items: [T], query: String, name: (T) -> String, brand: (T) -> String? = { _ in nil }, limit: Int) -> [T] {
        items
            .compactMap { item in score(name: name(item), brand: brand(item), query: query).map { (item, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}
