import CoreData
import SwiftUI

/// Eigenes Produkt erfassen, bearbeiten oder ein fremdes korrigieren (SPEC 5.5).
struct ProductEditorView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let existing: FoodProduct?
    let onSave: (FoodProduct) -> Void

    @State private var draft: ProductDraft
    @State private var showsScanner = false
    @State private var confirmsDelete = false
    /// Pro Produkt abwählbar, falls Mithelfen eingeschaltet ist (SPEC 5.11).
    @State private var sendsToOpenFoodFacts = true

    /// Was an Open Food Facts ginge – `nil`, wenn nichts oder Mithelfen aus.
    private var contribution: OpenFoodFactsContributor.Contribution? {
        guard app.preferences.contributesToOpenFoodFacts else { return nil }
        return OpenFoodFactsContributor.contribution(for: draft, isNew: existing == nil)
    }

    init(existing: FoodProduct? = nil, draft: ProductDraft = ProductDraft(), onSave: @escaping (FoodProduct) -> Void = { _ in }) {
        self.existing = existing
        self.onSave = onSave
        _draft = State(initialValue: existing.map(ProductDraft.init(product:)) ?? draft)
    }

    private var title: String {
        if existing != nil { return "Produkt bearbeite" }
        if draft.completesOpenFoodFacts { return "Produkt ergänze" }
        switch draft.origin {
        case .own: return "Nöis Produkt"
        case .offCopy, .blvCopy: return "Korrigiere"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if draft.completesOpenFoodFacts && existing == nil {
                    Section {
                        Text("Vo Open Food Facts übernoh, was da isch. Ergänz d Lücke – gspycheret wird's als dys eigete Produkt.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else if draft.origin != .own && existing == nil {
                    Section {
                        Text("Du machsch e eigeti Kopie. Ab jetz gwinnt dyni Version – o bim nächschte Scan.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Section {
                    TextField("Name", text: $draft.name)
                    TextField("Marke (fakultativ)", text: $draft.brand)
                    HStack {
                        TextField("Barcode (fakultativ)", text: $draft.barcode)
                            .keyboardType(.numberPad)
                            .font(.body.monospaced())
                        Button {
                            showsScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                        .buttonStyle(.borderless)
                    }
                    Picker("Art", selection: $draft.isLiquid) {
                        Text("Fescht (g)").tag(false)
                        Text("Flüssig (ml)").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                NutritionLabelScanSection(draft: $draft)

                Section {
                    NutrientInputs(nutrients: $draft.per100, isLiquid: draft.isLiquid)
                } header: {
                    Text("Nährwärt pro 100 \(draft.isLiquid ? "ml" : "g")")
                } footer: {
                    Text("Nume d Energie isch Pflicht. Läär heisst „unbekannt“, nid 0.")
                }

                Section {
                    ForEach($draft.portions) { $portion in
                        HStack {
                            TextField("z. B. Schiibe", text: $portion.name)
                            TextField("g", value: $portion.grams, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text(draft.isLiquid ? "ml" : "g")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .onDelete { draft.portions.remove(atOffsets: $0) }
                    Button {
                        draft.portions.append(ProductDraft.PortionDraft())
                    } label: {
                        Label("Portionsgrössi drzue", systemImage: "plus")
                    }
                } header: {
                    Text("Portionsgrössene")
                } footer: {
                    Text("Z. B. „1 Schiibe = 30 g“. Bim Erfasse chasch denn eifach „2 Schiibe“ wähle.")
                }

                if contribution != nil {
                    Section {
                        Toggle("A Open Food Facts schicke", isOn: $sendsToOpenFoodFacts)
                    } footer: {
                        Text(draft.completesOpenFoodFacts
                             ? "Schickt d Nährwärt pro 100 \(draft.isLiquid ? "ml" : "g") – so finde's angeri bim nächschte Scan. Öffentlech, Lizänz ODbL."
                             : "Schickt Barcode, Name, Marke u Nährwärt – so finde's angeri bim nächschte Scan. Öffentlech, Lizänz ODbL.")
                    }
                }

                if let existing {
                    Section {
                        Button("Produkt lösche", role: .destructive) { confirmsDelete = true }
                    } footer: {
                        Text("Scho erfassti Mahlzyte blybe, wie si sy.")
                    }
                    .confirmationDialog("Produkt lösche?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                        Button("Lösche", role: .destructive) {
                            app.store.deleteProduct(existing)
                            app.dataDidChange()
                            dismiss()
                        }
                    }
                }
            }
            .themedList()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") {
                        let sending = sendsToOpenFoodFacts ? contribution : nil
                        let product = app.store.saveProduct(draft, editing: existing)
                        app.dataDidChange()
                        OpenFoodFactsContributor.contributeIfEnabled(
                            sending, displayName: product.displayName, preferences: app.preferences
                        )
                        onSave(product)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
            .sheet(isPresented: $showsScanner) {
                CodeScannerView(mode: .barcode) { code in
                    draft.barcode = code
                }
            }
        }
    }
}
