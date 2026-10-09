import Foundation

/// Sucht über alle Quellen in der Reihenfolge aus SPEC 5.4.
///
/// Lokale Quellen (eigene Produkte, Favoriten, Rezepte, BLV bzw. Richtwerte)
/// antworten sofort. Open Food Facts kommt separat und nur, wenn erlaubt.
@MainActor
final class FoodSearchService {
    private let store: DataStore
    private let catalog: FoodCatalog
    private let preferences: AppPreferences

    init(store: DataStore, catalog: FoodCatalog = .shared, preferences: AppPreferences) {
        self.store = store
        self.catalog = catalog
        self.preferences = preferences
    }

    struct LocalResults {
        /// Bis drei Treffer quer über alle Quellen, in denen das Suchwort als
        /// ganzes Wort vorkommt – z. B. „Kartoffeln, roh“ bei „kartoffel“. Sie
        /// stehen nicht nochmals in den Abschnitten darunter.
        var best: [FoodCandidate] = []
        var own: [FoodCandidate]
        var recipes: [FoodCandidate]
        var remembered: [FoodCandidate]
        var catalog: [FoodCandidate]

        var isEmpty: Bool { best.isEmpty && own.isEmpty && recipes.isEmpty && remembered.isEmpty && catalog.isEmpty }
    }

    func localResults(for query: String) -> LocalResults {
        let own = FoodSearchRanking.rank(
            store.allProducts().compactMap { store.candidate(for: $0) },
            query: query,
            name: { "\($0.name) \($0.brand ?? "")" },
            limit: 20
        )
        let recipes = FoodSearchRanking.rank(
            store.allRecipes().compactMap { store.candidate(for: $0) },
            query: query,
            name: \.name,
            limit: 10
        )

        // Gemerkte fremde Treffer (Favoriten, zuletzt verwendet), ohne Doppel mit dem Katalog.
        let remembered = FoodSearchRanking.rank(
            store.fetch(ExternalFoodRef.self).compactMap { store.candidate(for: $0) },
            query: query,
            name: { "\($0.name) \($0.brand ?? "")" },
            limit: 10
        )
        let rememberedIds = Set(remembered.map(\.id))
        let favoriteCatalogIds = Set(
            store.fetch(ExternalFoodRef.self, predicate: NSPredicate(format: "isFavorite == YES AND sourceRaw == %@", ExternalFoodSource.blv.rawValue))
                .compactMap(\.externalId)
        )
        let catalogHits = catalog.search(query)
            .map { catalog.candidate($0, isFavorite: favoriteCatalogIds.contains($0.id)) }
            .filter { !rememberedIds.contains($0.id) }

        let best = Self.bestHits([own, recipes, remembered, catalogHits], query: query)
        let bestIds = Set(best.map(\.id))
        return LocalResults(
            best: best,
            own: own.filter { !bestIds.contains($0.id) },
            recipes: recipes.filter { !bestIds.contains($0.id) },
            remembered: remembered.filter { !bestIds.contains($0.id) },
            catalog: catalogHits.filter { !bestIds.contains($0.id) }
        )
    }

    /// Die besten Treffer aus allen Abschnitten. Bei gleicher Punktzahl gewinnt
    /// die Reihenfolge der Quellen (eigene Produkte zuerst).
    nonisolated static func bestHits(_ sections: [[FoodCandidate]], query: String, limit: Int = 3) -> [FoodCandidate] {
        var seen = Set<String>()
        let scored = sections.flatMap { $0 }.enumerated().compactMap { index, candidate -> (Int, Int, FoodCandidate)? in
            guard seen.insert(candidate.id).inserted,
                  let score = FoodSearchRanking.score(name: searchName(candidate), query: query),
                  score >= FoodSearchRanking.wholeWordScore
            else { return nil }
            return (score, index, candidate)
        }
        return scored
            .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 < $1.1 }
            .prefix(limit)
            .map(\.2)
    }

    nonisolated static func searchName(_ candidate: FoodCandidate) -> String {
        "\(candidate.name) \(candidate.brand ?? "")"
    }

    /// `nil` heisst: Open Food Facts nicht erreichbar. Leer heisst: nichts gefunden
    /// oder abgeschaltet.
    func remoteResults(for query: String) async -> [FoodCandidate]? {
        guard preferences.usesOpenFoodFacts else { return [] }
        guard let products = await OpenFoodFactsClient.search(query) else { return nil }
        let favorites = Set(
            store.fetch(ExternalFoodRef.self, predicate: NSPredicate(format: "isFavorite == YES AND sourceRaw == %@", ExternalFoodSource.off.rawValue))
                .compactMap(\.externalId)
        )
        // Gleiche Regel wie lokal: „Kartoffeln“ vor „Kartoffelpüree“. Bei gleicher
        // Punktzahl bleibt die Reihenfolge von Open Food Facts (Schweizer zuerst).
        return FoodSearchRanking.sort(
            products.map { $0.candidate(isFavorite: favorites.contains($0.code)) },
            query: query,
            name: Self.searchName
        )
    }

    enum BarcodeResult: Equatable {
        /// Eigenes Produkt – deine Version gewinnt (Q29).
        case own(FoodCandidate)
        case openFoodFacts(FoodCandidate)
        /// Open Food Facts kennt den Code, aber nicht alle nötigen Werte:
        /// Formular mit allem, was da ist.
        case incomplete(ProductDraft)
        /// Niemand kennt den Code: Formular „Nöis Produkt“ mit Barcode.
        case unknown(String)
        /// Kein Netz, und der Code ist nicht bei den eigenen Produkten.
        case offline(String)
    }

    func lookup(barcode: String) async -> BarcodeResult {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        if let product = store.product(barcode: code), let candidate = store.candidate(for: product) {
            return .own(candidate)
        }
        if let ref = store.externalRef(source: .off, externalId: code), let candidate = store.candidate(for: ref) {
            return .openFoodFacts(candidate)
        }
        guard preferences.usesOpenFoodFacts else { return .unknown(code) }
        switch await OpenFoodFactsClient.lookup(barcode: code) {
        case .found(let product):
            let isFavorite = store.externalRef(source: .off, externalId: product.code)?.isFavorite ?? false
            let candidate = product.candidate(isFavorite: isFavorite)
            // Gescannt heisst gemerkt: Das Produkt ist danach auch über die Suche
            // zu finden – ohne Netz und auch, wenn Open Food Facts es dort nicht zeigt.
            store.rememberExternal(candidate)
            store.save()
            return .openFoodFacts(candidate)
        case .incomplete(let product):
            return .incomplete(product.draft)
        case .notFound:
            return .unknown(code)
        case .unavailable:
            return .offline(code)
        }
    }
}
