import CoreData
import SwiftUI

/// Eigene Produkte verwalten (SPEC 5.5).
struct ProductListView: View {
    @Environment(AppEnvironment.self) private var app
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var products: FetchedResults<FoodProduct>

    @State private var editing: FoodProduct?
    @State private var creating = false
    @State private var query = ""

    private var filtered: [FoodProduct] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return Array(products) }
        return FoodSearchRanking.rank(Array(products), query: text, name: { "\($0.displayName) \($0.brand ?? "")" }, limit: 200)
    }

    var body: some View {
        List {
            if products.isEmpty {
                EmptyStateView(
                    symbol: "shippingbox",
                    title: "No kener eigete Produkt",
                    message: "Produkt, wo du säuber erfasst oder korrigiersch, erschyne hie.",
                    actionTitle: "Nöis Produkt"
                ) { creating = true }
                .listRowBackground(Color.clear)
            }
            ForEach(filtered) { product in
                Button {
                    editing = product
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.displayName).foregroundStyle(Theme.textPrimary)
                            HStack(spacing: 6) {
                                if let brand = product.brand, !brand.isEmpty { Text(brand) }
                                if product.barcodeText != nil {
                                    Image(systemName: "barcode")
                                }
                                if product.origin != .own {
                                    Text("Korrektur")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                        if product.isFavorite {
                            Image(systemName: "star.fill").foregroundStyle(Theme.warning)
                        }
                        Text("\(NumberText.kcal(product.per100.kcal ?? 0)) kcal")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Theme.nutrition)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button {
                        product.isFavorite.toggle()
                        app.dataDidChange()
                    } label: {
                        Label("Favorit", systemImage: "star")
                    }
                    .tint(Theme.warning)
                }
            }
            .onDelete { offsets in
                offsets.map { filtered[$0] }.forEach(app.store.deleteProduct)
                app.dataDidChange()
            }
        }
        .themedList()
        .searchable(text: $query, prompt: "Produkt sueche")
        .navigationTitle("Eigeti Produkt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editing) { product in
            ProductEditorView(existing: product)
        }
        .sheet(isPresented: $creating) {
            ProductEditorView()
        }
    }
}

/// Alle Favoriten auf einen Blick.
struct FavoritesListView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var favorites: [FoodCandidate] = []

    var body: some View {
        List {
            if favorites.isEmpty {
                EmptyStateView(
                    symbol: "star",
                    title: "No kener Favorite",
                    message: "Bim Erfasse dr Stärn neben emne Lebensmittu tippe."
                )
                .listRowBackground(Color.clear)
            }
            ForEach(favorites) { candidate in
                CandidateRow(candidate: candidate) {
                    app.store.setFavorite(false, for: candidate)
                    reload()
                }
            }
        }
        .themedList()
        .navigationTitle("Favorite")
        .task(id: app.revision) { reload() }
    }

    private func reload() {
        favorites = app.store.favoriteCandidates()
    }
}
