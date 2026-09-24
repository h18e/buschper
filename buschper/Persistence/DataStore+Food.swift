import CoreData
import Foundation

/// Entwurf eines eigenen Produkts (SPEC 5.5).
struct ProductDraft: Equatable {
    var name = ""
    var brand = ""
    var barcode = ""
    var isLiquid = false
    var per100 = Nutrients()
    var portions: [PortionDraft] = []
    var origin: ProductOrigin = .own
    var originExternalId: String?

    struct PortionDraft: Equatable, Identifiable {
        var id = UUID()
        var name = ""
        var grams: Double = 0
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && per100.kcal != nil
    }

    init() {}

    init(product: FoodProduct) {
        name = product.name ?? ""
        brand = product.brand ?? ""
        barcode = product.barcode ?? ""
        isLiquid = product.isLiquid
        per100 = product.per100
        portions = product.portionList.map { PortionDraft(name: $0.name ?? "", grams: $0.grams) }
        origin = product.origin
        originExternalId = product.originExternalId
    }

    /// Korrektur eines fremden Produkts: Vorlage für die eigene Kopie (Q29).
    init(copying candidate: FoodCandidate) {
        name = candidate.name
        brand = candidate.brand ?? ""
        barcode = candidate.barcode ?? ""
        isLiquid = candidate.isLiquid
        per100 = candidate.per100
        portions = candidate.portions.compactMap { choice in
            choice.name.map { PortionDraft(name: $0, grams: choice.gramsPerUnit) }
        }
        switch candidate.source {
        case .openFoodFacts(let code):
            origin = .offCopy
            originExternalId = code
        case .catalog(let id):
            origin = .blvCopy
            originExternalId = id
        case .product, .recipe:
            origin = .own
        }
    }
}

extension DataStore {

    // MARK: - Eigene Produkte

    func allProducts() -> [FoodProduct] {
        fetch(FoodProduct.self, sort: [NSSortDescriptor(key: "name", ascending: true)])
    }

    func product(barcode: String) -> FoodProduct? {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        // Die neueste Version gewinnt, falls es aus Versehen zwei gibt.
        return fetch(
            FoodProduct.self,
            predicate: NSPredicate(format: "barcode == %@", code),
            sort: [NSSortDescriptor(key: "updatedAt", ascending: false)],
            limit: 1
        ).first
    }

    @discardableResult
    func saveProduct(_ draft: ProductDraft, editing existing: FoodProduct? = nil) -> FoodProduct {
        let product = existing ?? {
            let product = FoodProduct(context: context)
            product.id = UUID()
            product.createdAt = Date()
            return product
        }()
        product.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        product.brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        product.barcode = draft.barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        product.isLiquid = draft.isLiquid
        product.per100 = draft.per100
        product.origin = draft.origin
        product.originExternalId = draft.originExternalId ?? ""
        product.updatedAt = Date()

        product.portionList.forEach(context.delete)
        for (index, portion) in draft.portions.enumerated() where portion.grams > 0 {
            let size = PortionSize(context: context)
            size.id = UUID()
            size.name = portion.name.trimmingCharacters(in: .whitespacesAndNewlines)
            size.grams = portion.grams
            size.sortIndex = Int32(index)
            size.product = product
        }
        save()
        return product
    }

    func deleteProduct(_ product: FoodProduct) {
        context.delete(product)
        save()
    }

    func candidate(for product: FoodProduct) -> FoodCandidate? {
        guard let id = product.id else { return nil }
        let label: String
        switch product.origin {
        case .own: label = "Eigets Produkt"
        case .offCopy: label = "Eigeti Korrektur (Open Food Facts)"
        case .blvCopy: label = "Eigeti Korrektur"
        }
        return FoodCandidate(
            source: .product(id),
            name: product.displayName,
            brand: (product.brand?.isEmpty == false) ? product.brand : nil,
            barcode: product.barcodeText,
            isLiquid: product.isLiquid,
            per100: product.per100,
            portions: product.portionChoices,
            isFavorite: product.isFavorite,
            sourceLabel: label
        )
    }

    // MARK: - Fremde Produkte merken

    func externalRef(source: ExternalFoodSource, externalId: String) -> ExternalFoodRef? {
        fetch(
            ExternalFoodRef.self,
            predicate: NSPredicate(format: "sourceRaw == %@ AND externalId == %@", source.rawValue, externalId),
            limit: 1
        ).first
    }

    /// Ein fremder Treffer wird gemerkt, sobald er geloggt oder zum Favoriten wird.
    @discardableResult
    func rememberExternal(_ candidate: FoodCandidate) -> ExternalFoodRef? {
        let key: (ExternalFoodSource, String)
        switch candidate.source {
        case .catalog(let id): key = (.blv, id)
        case .openFoodFacts(let code): key = (.off, code)
        case .product, .recipe: return nil
        }
        let ref = externalRef(source: key.0, externalId: key.1) ?? {
            let ref = ExternalFoodRef(context: context)
            ref.id = UUID()
            ref.source = key.0
            ref.externalId = key.1
            return ref
        }()
        ref.name = candidate.name
        ref.brand = candidate.brand ?? ""
        ref.isLiquid = candidate.isLiquid
        ref.per100 = candidate.per100
        return ref
    }

    func candidate(for ref: ExternalFoodRef) -> FoodCandidate? {
        guard let externalId = ref.externalId, !externalId.isEmpty else { return nil }
        let source: FoodCandidate.Source
        let label: String
        switch ref.source {
        case .blv:
            source = .catalog(externalId)
            label = FoodCatalog.shared.sourceLabel
        case .off:
            source = .openFoodFacts(externalId)
            label = "Open Food Facts"
        }
        return FoodCandidate(
            source: source,
            name: ref.name ?? "",
            brand: (ref.brand?.isEmpty == false) ? ref.brand : nil,
            barcode: ref.source == .off ? externalId : nil,
            isLiquid: ref.isLiquid,
            per100: ref.per100,
            portions: [PortionChoice(name: nil, gramsPerUnit: 1)],
            isFavorite: ref.isFavorite,
            sourceLabel: label
        )
    }

    // MARK: - Favoriten und zuletzt verwendet

    func setFavorite(_ favorite: Bool, for candidate: FoodCandidate) {
        switch candidate.source {
        case .product(let id):
            object(FoodProduct.self, id: id)?.isFavorite = favorite
        case .recipe(let id):
            object(Recipe.self, id: id)?.isFavorite = favorite
        case .catalog, .openFoodFacts:
            rememberExternal(candidate)?.isFavorite = favorite
        }
        save()
    }

    func favoriteCandidates() -> [FoodCandidate] {
        let products = fetch(FoodProduct.self, predicate: NSPredicate(format: "isFavorite == YES"))
            .compactMap { candidate(for: $0) }
        let externals = fetch(ExternalFoodRef.self, predicate: NSPredicate(format: "isFavorite == YES"))
            .compactMap { candidate(for: $0) }
        let recipes = fetch(Recipe.self, predicate: NSPredicate(format: "isFavorite == YES"))
            .compactMap { candidate(for: $0) }
        return (products + recipes + externals).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func recentCandidates(limit: Int = 15) -> [FoodCandidate] {
        let predicate = NSPredicate(format: "lastUsedAt != nil")
        let sort = [NSSortDescriptor(key: "lastUsedAt", ascending: false)]
        let products = fetch(FoodProduct.self, predicate: predicate, sort: sort, limit: limit)
            .map { ($0.lastUsedAt ?? .distantPast, candidate(for: $0)) }
        let externals = fetch(ExternalFoodRef.self, predicate: predicate, sort: sort, limit: limit)
            .map { ($0.lastUsedAt ?? .distantPast, candidate(for: $0)) }
        let recipes = fetch(Recipe.self, predicate: predicate, sort: sort, limit: limit)
            .map { ($0.lastUsedAt ?? .distantPast, candidate(for: $0)) }
        return (products + externals + recipes)
            .sorted { $0.0 > $1.0 }
            .compactMap(\.1)
            .prefix(limit)
            .map { $0 }
    }

    /// Nach dem Loggen: Nutzung vermerken, damit „Zletscht bruucht“ stimmt.
    func markUsed(_ item: BasketItem, at date: Date = Date()) {
        guard let sourceId = item.sourceId else { return }
        switch item.kind {
        case .product:
            if let id = UUID(uuidString: sourceId) { object(FoodProduct.self, id: id)?.markUsed(at: date) }
        case .recipe:
            if let id = UUID(uuidString: sourceId) { object(Recipe.self, id: id)?.markUsed(at: date) }
        case .external:
            let parts = sourceId.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return }
            let source: ExternalFoodSource = parts[0] == "off" ? .off : .blv
            externalRef(source: source, externalId: parts[1])?.markUsed(at: date)
        case .quick:
            break
        }
    }

    // MARK: - Rezepte als Treffer (ausgebaut in Schritt 6)

    func candidate(for recipe: Recipe) -> FoodCandidate? {
        guard let id = recipe.id else { return nil }
        return FoodCandidate(
            source: .recipe(id),
            name: recipe.displayName,
            brand: nil,
            barcode: nil,
            isLiquid: false,
            per100: recipe.perServing,
            portions: [],
            isFavorite: recipe.isFavorite,
            sourceLabel: "Rezept"
        )
    }

    // MARK: - Mahlzeiten

    func meals(on day: Date) -> [Meal] {
        fetch(
            Meal.self,
            predicate: DataStore.dayPredicate("timestamp", day: day),
            sort: [NSSortDescriptor(key: "timestamp", ascending: true)]
        )
    }

    func meals(from start: Date, to end: Date) -> [Meal] {
        fetch(
            Meal.self,
            predicate: DataStore.rangePredicate("timestamp", from: start, to: end),
            sort: [NSSortDescriptor(key: "timestamp", ascending: true)]
        )
    }

    /// Sichert das Chörbli als neue Mahlzeit – oder hängt es an eine bestehende an.
    @discardableResult
    func saveMeal(items: [BasketItem], timestamp: Date, category: MealCategory, title: String? = nil, into existing: Meal? = nil) -> Meal? {
        guard !items.isEmpty || existing != nil else { return nil }
        let meal = existing ?? {
            let meal = Meal(context: context)
            meal.id = UUID()
            meal.createdAt = Date()
            return meal
        }()
        meal.timestamp = timestamp
        meal.category = category
        if let title { meal.title = title }
        meal.updatedAt = Date()

        var index = (meal.entryList.map(\.sortIndex).max() ?? -1) + 1
        for item in items {
            let entry = FoodEntry(context: context)
            entry.id = UUID()
            apply(item, to: entry)
            entry.sortIndex = index
            entry.meal = meal
            index += 1
            markUsed(item, at: timestamp)
        }
        if let id = meal.id {
            markForHealthWrite(localId: id, kind: .meal)
        }
        return meal
    }

    func apply(_ item: BasketItem, to entry: FoodEntry) {
        entry.name = item.name
        entry.amount = item.count
        entry.unitLabel = item.unitLabel
        entry.grams = item.storedGrams
        entry.isLiquid = item.isLiquid
        entry.total = item.total
        entry.kind = item.kind
        entry.sourceId = item.sourceId ?? ""
        entry.servings = item.kind == .recipe ? item.count : 0
    }

    func deleteMeal(_ meal: Meal) {
        if let id = meal.id {
            markForHealthDelete(localId: id, kind: .meal)
        }
        context.delete(meal)
    }

    func deleteEntry(_ entry: FoodEntry) {
        let meal = entry.meal
        context.delete(entry)
        guard let meal else { return }
        if meal.entryList.filter({ !$0.isDeleted }).isEmpty {
            deleteMeal(meal)
        } else if let id = meal.id {
            meal.updatedAt = Date()
            markForHealthWrite(localId: id, kind: .meal)
        }
    }

    /// Nach jeder Änderung an Einträgen einer Mahlzeit.
    func mealDidChange(_ meal: Meal) {
        meal.updatedAt = Date()
        if let id = meal.id {
            markForHealthWrite(localId: id, kind: .meal)
        }
    }
}
