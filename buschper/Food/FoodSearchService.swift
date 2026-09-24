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
        var own: [FoodCandidate]
        var recipes: [FoodCandidate]
        var remembered: [FoodCandidate]
        var catalog: [FoodCandidate]

        var isEmpty: Bool { own.isEmpty && recipes.isEmpty && remembered.isEmpty && catalog.isEmpty }
    }

    func localResults(for query: String) -> LocalResults {
        let own = FoodSearchRanking.rank(
            store.allProducts().compactMap { store.candidate(for: $0) },
            query: query,
            name: { "\($0.name) \($0.brand ?? "")" },
            limit: 20
        )
        let recipes = FoodSearchRanking.rank(
            store.fetch(Recipe.self).compactMap { store.candidate(for: $0) },
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

        return LocalResults(own: own, recipes: recipes, remembered: remembered, catalog: catalogHits)
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
        return products.map { $0.candidate(isFavorite: favorites.contains($0.code)) }
    }

    enum BarcodeResult: Equatable {
        /// Eigenes Produkt – deine Version gewinnt (Q29).
        case own(FoodCandidate)
        case openFoodFacts(FoodCandidate)
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
            return .openFoodFacts(product.candidate(isFavorite: isFavorite))
        case .notFound:
            return .unknown(code)
        case .unavailable:
            return .offline(code)
        }
    }
}
