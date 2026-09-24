import CoreData
import SwiftUI

/// „Ässe“: suchen, scannen, ins Chörbli legen, einmal sichern (SPEC 5.3).
struct AddFoodView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Wenn gesetzt, werden die Einträge an diese Mahlzeit angehängt.
    var existingMeal: Meal?

    @State private var timestamp: Date
    @State private var category: MealCategory
    @State private var categoryTouched = false
    @State private var query = ""
    @State private var basket: [BasketItem] = []

    @State private var local: FoodSearchService.LocalResults?
    @State private var remote: [FoodCandidate]?
    @State private var remoteState: RemoteState = .idle
    @State private var favorites: [FoodCandidate] = []
    @State private var recents: [FoodCandidate] = []
    @State private var ownProducts: [FoodCandidate] = []

    @State private var picking: FoodCandidate?
    @State private var editingBasketItem: BasketItem?
    @State private var showsScanner = false
    @State private var showsQuickEntry = false
    @State private var showsBasket = false
    @State private var productDraft: ProductDraftSheet?
    @State private var scanMessage: String?
    @State private var showsQRScanner = false
    @State private var importing: SharedMeal?
    @State private var yesterdayEntries: [FoodEntry] = []

    private enum RemoteState: Equatable {
        case idle, loading, offline, done
    }

    /// Hülle, damit ein Entwurf als `sheet(item:)` aufgehen kann.
    struct ProductDraftSheet: Identifiable {
        let id = UUID()
        var draft: ProductDraft
        var existing: FoodProduct?
    }

    init(existingMeal: Meal? = nil, date: Date = Date()) {
        self.existingMeal = existingMeal
        let start = existingMeal?.timestamp ?? date
        _timestamp = State(initialValue: start)
        _category = State(initialValue: existingMeal?.category ?? MealCategory.suggested(for: start))
        _categoryTouched = State(initialValue: existingMeal != nil)
    }

    private var search: FoodSearchService {
        FoodSearchService(store: app.store, preferences: app.preferences)
    }

    private var basketTotal: Nutrients {
        NutrientSum(basket.map(\.total)).values
    }

    var body: some View {
        NavigationStack {
            List {
                if existingMeal == nil {
                    Section {
                        DatePicker("Zyt", selection: $timestamp)
                        Picker("Mahlzyt", selection: Binding(
                            get: { category },
                            set: { category = $0; categoryTouched = true }
                        )) {
                            ForEach(MealCategory.allCases) { item in
                                Label(item.label, systemImage: item.symbolName).tag(item)
                            }
                        }
                    }
                }

                actionsSection

                if let scanMessage {
                    Section {
                        Text(scanMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    browseSections
                } else {
                    resultSections
                }
            }
            .themedList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Lebensmittu sueche")
            .navigationTitle(existingMeal == nil ? "Ässe" : "Drzue tue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") { saveMeal() }
                        .disabled(basket.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) { basketBar }
            .onChange(of: timestamp) { _, newValue in
                if !categoryTouched { category = MealCategory.suggested(for: newValue) }
            }
            .task { reloadLists() }
            .task(id: YesterdayKey(category: category, day: Calendar.current.startOfDay(for: timestamp))) {
                loadYesterday()
            }
            .task(id: query) { await runSearch() }
            .sheet(item: $picking) { candidate in
                AmountPickerView(candidate: candidate) { portion, count in
                    app.store.rememberExternal(candidate)
                    basket.append(BasketItem.from(candidate, portion: portion, count: count))
                }
            }
            .sheet(item: $editingBasketItem) { item in
                basketItemEditor(item)
            }
            .sheet(isPresented: $showsQuickEntry) {
                QuickEntryView { basket.append($0) }
            }
            .sheet(isPresented: $showsScanner) {
                CodeScannerView(mode: .barcode) { code in
                    Task { await handleBarcode(code) }
                }
            }
            .sheet(item: $productDraft) { sheet in
                ProductEditorView(existing: sheet.existing, draft: sheet.draft) { product in
                    reloadLists()
                    if let candidate = app.store.candidate(for: product) {
                        // Nach dem Sichern direkt die Menge wählen.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { picking = candidate }
                    }
                }
            }
            .sheet(isPresented: $showsBasket) {
                basketSheet
            }
            .sheet(isPresented: $showsQRScanner) {
                CodeScannerView(mode: .qrCode) { code in
                    if let url = URL(string: code), let meal = try? MealShareCodec.decode(url: url) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { importing = meal }
                    } else {
                        scanMessage = "Das isch ke QR-Code vo buschper."
                    }
                }
            }
            .sheet(item: $importing) { meal in
                ImportMealView(meal: meal)
            }
        }
    }

    // MARK: - Abschnitte

    private var actionsSection: some View {
        Section {
            HStack(spacing: 10) {
                actionButton("Barcode", "barcode.viewfinder") { showsScanner = true }
                actionButton("Schnäll-Iitrag", "bolt.fill") { showsQuickEntry = true }
                actionButton("Nöis Produkt", "plus.square.fill") {
                    productDraft = ProductDraftSheet(draft: ProductDraft(), existing: nil)
                }
                if existingMeal == nil {
                    actionButton("QR-Code", "qrcode.viewfinder") { showsQRScanner = true }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
    }

    private func actionButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.nutrition)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var browseSections: some View {
        if !yesterdayEntries.isEmpty {
            Section {
                Button {
                    basket += yesterdayEntries.map { app.store.basketItem(from: $0) }
                    yesterdayEntries = []
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Wie geschter: \(category.label)", systemImage: "arrow.uturn.backward.circle.fill")
                            .foregroundStyle(Theme.nutrition)
                        Text(yesterdayEntries.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        if !favorites.isEmpty {
            Section("Favorite") { candidateRows(favorites) }
        }
        if !recents.isEmpty {
            Section("Zletscht bruucht") { candidateRows(recents) }
        }
        if !ownProducts.isEmpty {
            Section("Eigeti Produkt") { candidateRows(ownProducts) }
        }
        if favorites.isEmpty && recents.isEmpty && ownProducts.isEmpty {
            Section {
                Text("Obe sueche, en Barcode scanne oder e Schnäll-Iitrag mache. Was du bruuchsch, erschint speter hie.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        if let local {
            if !local.own.isEmpty {
                Section("Eigeti Produkt") { candidateRows(local.own) }
            }
            if !local.recipes.isEmpty {
                Section("Rezept") { candidateRows(local.recipes) }
            }
            if !local.remembered.isEmpty {
                Section("Gmerkt") { candidateRows(local.remembered) }
            }
            if !local.catalog.isEmpty {
                Section {
                    candidateRows(local.catalog)
                } header: {
                    Text(FoodCatalog.shared.isBLV ? "Schwiizer Nährwärtdatebank" : "Grundnahrigsmittel (Richtwärt)")
                }
            }
        }
        Section {
            switch remoteState {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Frage Open Food Facts …").foregroundStyle(Theme.textSecondary)
                }
            case .offline:
                Label("Open Food Facts isch grad nid erreichbar.", systemImage: "wifi.slash")
                    .foregroundStyle(Theme.textSecondary)
            case .done, .idle:
                if let remote, !remote.isEmpty {
                    candidateRows(remote)
                } else if remoteState == .done {
                    Text(app.preferences.usesOpenFoodFacts ? "Nüt gfunde." : "Open Food Facts isch abgschaltet.")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        } header: {
            Text("Open Food Facts")
        }
    }

    private func candidateRows(_ candidates: [FoodCandidate]) -> some View {
        ForEach(candidates) { candidate in
            Button {
                picking = candidate
            } label: {
                CandidateRow(candidate: candidate) {
                    app.store.setFavorite(!candidate.isFavorite, for: candidate)
                    reloadLists()
                    Task { await runSearch(debounce: false) }
                }
            }
            .buttonStyle(.plain)
            .contextMenu { candidateMenu(candidate) }
        }
    }

    @ViewBuilder
    private func candidateMenu(_ candidate: FoodCandidate) -> some View {
        switch candidate.source {
        case .product(let id):
            if let product = app.store.object(FoodProduct.self, id: id) {
                Button {
                    productDraft = ProductDraftSheet(draft: ProductDraft(product: product), existing: product)
                } label: {
                    Label("Bearbeite", systemImage: "pencil")
                }
            }
        case .catalog, .openFoodFacts:
            Button {
                productDraft = ProductDraftSheet(draft: ProductDraft(copying: candidate), existing: nil)
            } label: {
                Label("Korrigiere (eigeti Kopie)", systemImage: "pencil")
            }
        case .recipe:
            EmptyView()
        }
        Button {
            app.store.setFavorite(!candidate.isFavorite, for: candidate)
            reloadLists()
        } label: {
            Label(candidate.isFavorite ? "Kei Favorit meh" : "Als Favorit", systemImage: "star")
        }
    }

    // MARK: - Chörbli

    @ViewBuilder
    private var basketBar: some View {
        if !basket.isEmpty {
            Button {
                showsBasket = true
            } label: {
                HStack {
                    Image(systemName: "basket.fill")
                        .foregroundStyle(Theme.background)
                        .frame(width: 34, height: 34)
                        .background(Theme.nutrition, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(basket.count) \(basket.count == 1 ? "Iitrag" : "Iiträg") im Chörbli")
                            .font(.subheadline.weight(.semibold))
                        NutrientLine(nutrients: basketTotal)
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var basketSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(basket) { item in
                        Button {
                            showsBasket = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editingBasketItem = item }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).foregroundStyle(Theme.textPrimary)
                                Text(item.amountLabel).font(.caption).foregroundStyle(Theme.textSecondary)
                                NutrientLine(nutrients: item.total)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { basket.remove(atOffsets: $0) }
                } footer: {
                    NutrientLine(nutrients: basketTotal)
                }
            }
            .themedList()
            .navigationTitle("Chörbli")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showsBasket = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func basketItemEditor(_ item: BasketItem) -> some View {
        if item.kind == .quick {
            QuickEntryView(initial: item) { updated in replace(updated) }
        } else if let per100 = item.per100 {
            AmountPickerView(
                title: item.name,
                isLiquid: item.isLiquid,
                isRecipe: item.kind == .recipe,
                per100: per100,
                portions: portionChoices(for: item),
                initialPortion: item.portion,
                initialCount: item.count,
                confirmTitle: "Übernäh"
            ) { portion, count in
                var updated = item
                updated.portion = portion
                updated.count = count
                replace(updated)
            }
        }
    }

    private func portionChoices(for item: BasketItem) -> [PortionChoice] {
        if item.kind == .product, let sourceId = item.sourceId, let id = UUID(uuidString: sourceId),
           let product = app.store.object(FoodProduct.self, id: id) {
            return product.portionChoices
        }
        return [PortionChoice(name: nil, gramsPerUnit: 1)]
    }

    private func replace(_ item: BasketItem) {
        if let index = basket.firstIndex(where: { $0.id == item.id }) {
            basket[index] = item
        }
    }

    // MARK: - Aktionen

    private struct YesterdayKey: Hashable {
        var category: MealCategory
        var day: Date
    }

    /// „Wie geschter“: dieselbe Kategorie vom Vortag, solange das Chörbli leer ist.
    private func loadYesterday() {
        guard existingMeal == nil, basket.isEmpty else {
            yesterdayEntries = []
            return
        }
        let yesterday = DayMath.previousDay(of: timestamp)
        yesterdayEntries = app.store.entries(category: category, on: yesterday)
    }

    private func reloadLists() {
        favorites = app.store.favoriteCandidates()
        recents = app.store.recentCandidates()
        ownProducts = app.store.allProducts().prefix(20).compactMap { app.store.candidate(for: $0) }
    }

    private func runSearch(debounce: Bool = true) async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            local = nil
            remote = nil
            remoteState = .idle
            return
        }
        local = search.localResults(for: text)
        guard text.count >= 3 else {
            remote = nil
            remoteState = .idle
            return
        }
        if debounce {
            // Erst fragen, wenn eine halbe Sekunde nicht mehr getippt wurde.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
        }
        remoteState = .loading
        let results = await search.remoteResults(for: text)
        guard !Task.isCancelled else { return }
        remote = results
        remoteState = results == nil ? .offline : .done
    }

    private func handleBarcode(_ code: String) async {
        scanMessage = nil
        switch await search.lookup(barcode: code) {
        case .own(let candidate), .openFoodFacts(let candidate):
            picking = candidate
        case .unknown(let code):
            scanMessage = "Dä Barcode kennt no niemer. Erfass ds Produkt einisch – ab em nächschte Scan isch es da."
            var draft = ProductDraft()
            draft.barcode = code
            productDraft = ProductDraftSheet(draft: draft, existing: nil)
        case .offline(let code):
            scanMessage = "Kes Netz: Open Food Facts isch nid erreichbar. Du chasch ds Produkt säuber erfasse."
            var draft = ProductDraft()
            draft.barcode = code
            productDraft = ProductDraftSheet(draft: draft, existing: nil)
        }
    }

    private func saveMeal() {
        app.store.saveMeal(items: basket, timestamp: timestamp, category: category, into: existingMeal)
        app.dataDidChange()
        dismiss()
    }
}
