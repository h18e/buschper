import CoreData
import SwiftUI

/// Zutat für ein Rezept suchen – dieselben Quellen wie beim Erfassen, aber ohne
/// Rezepte, weil Rezepte nicht verschachtelt werden (Q17).
struct IngredientPickerView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let onPick: (RecipeDraft.Ingredient) -> Void

    @State private var query = ""
    @State private var local: FoodSearchService.LocalResults?
    @State private var remote: [FoodCandidate]?
    @State private var loadingRemote = false
    @State private var recents: [FoodCandidate] = []
    @State private var picking: FoodCandidate?
    @State private var showsScanner = false
    @State private var creating = false
    @State private var message: String?

    private var search: FoodSearchService {
        FoodSearchService(store: app.store, preferences: app.preferences)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            showsScanner = true
                        } label: {
                            Label("Barcode", systemImage: "barcode.viewfinder")
                        }
                        Spacer()
                        Button {
                            creating = true
                        } label: {
                            Label("Nöis Produkt", systemImage: "plus.square")
                        }
                    }
                    .buttonStyle(.borderless)
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    if !recents.isEmpty {
                        Section("Zletscht bruucht") { rows(recents) }
                    }
                } else if let local {
                    if !local.own.isEmpty { Section("Eigeti Produkt") { rows(local.own) } }
                    if !local.remembered.isEmpty { Section("Gmerkt") { rows(local.remembered) } }
                    if !local.catalog.isEmpty {
                        Section(FoodCatalog.shared.isBLV ? "Schwiizer Nährwärtdatebank" : "Grundnahrigsmittel (Richtwärt)") {
                            rows(local.catalog)
                        }
                    }
                    Section("Open Food Facts") {
                        if loadingRemote {
                            ProgressView()
                        } else if let remote, !remote.isEmpty {
                            rows(remote)
                        } else if remote == nil {
                            Label("Nid erreichbar", systemImage: "wifi.slash").foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Nüt gfunde.").foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .themedList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zuetat sueche")
            .navigationTitle("Zuetat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
            }
            .task { recents = app.store.recentCandidates().filter { !$0.isRecipe } }
            .task(id: query) { await runSearch() }
            .sheet(item: $picking) { candidate in
                AmountPickerView(candidate: candidate) { portion, count in
                    app.store.rememberExternal(candidate)
                    let item = BasketItem.from(candidate, portion: portion, count: count)
                    onPick(RecipeDraft.Ingredient(
                        name: candidate.displayName,
                        amountG: item.grams,
                        isLiquid: candidate.isLiquid,
                        per100: candidate.per100,
                        sourceKind: item.kind,
                        sourceId: item.sourceId
                    ))
                    dismiss()
                }
            }
            .sheet(isPresented: $showsScanner) {
                CodeScannerView(mode: .barcode) { code in
                    Task {
                        switch await search.lookup(barcode: code) {
                        case .own(let candidate), .openFoodFacts(let candidate):
                            picking = candidate
                        case .unknown, .offline:
                            message = "Dä Barcode isch unbekannt. Erfass ds Produkt mit „Nöis Produkt“."
                        }
                    }
                }
            }
            .sheet(isPresented: $creating) {
                ProductEditorView { product in
                    if let candidate = app.store.candidate(for: product) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { picking = candidate }
                    }
                }
            }
        }
    }

    private func rows(_ candidates: [FoodCandidate]) -> some View {
        ForEach(candidates) { candidate in
            Button { picking = candidate } label: { CandidateRow(candidate: candidate) }
                .buttonStyle(.plain)
        }
    }

    private func runSearch() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { local = nil; remote = nil; return }
        var results = search.localResults(for: text)
        results.recipes = []
        local = results
        guard text.count >= 3 else { remote = []; return }
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        loadingRemote = true
        let found = await search.remoteResults(for: text)
        guard !Task.isCancelled else { return }
        remote = found
        loadingRemote = false
    }
}
