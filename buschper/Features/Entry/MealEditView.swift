import CoreData
import SwiftUI

/// Eine erfasste Mahlzeit bearbeiten: Zeit, Kategorie, Einträge (SPEC 5.9).
struct MealEditView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var meal: Meal

    @State private var editingEntry: FoodEntry?
    @State private var showsAddFood = false
    @State private var confirmsDelete = false
    @State private var copying: CopyRequest?
    @State private var sharing: SharedMeal?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Zyt", selection: Binding(
                        get: { meal.timestamp ?? Date() },
                        set: { meal.timestamp = $0; changed() }
                    ))
                    Picker("Mahlzyt", selection: Binding(
                        get: { meal.category },
                        set: { meal.category = $0; changed() }
                    )) {
                        ForEach(MealCategory.allCases) { item in
                            Label(item.label, systemImage: item.symbolName).tag(item)
                        }
                    }
                    TextField("Titel (fakultativ)", text: Binding(
                        get: { meal.title ?? "" },
                        set: { meal.title = $0; changed() }
                    ))
                }

                Section {
                    ForEach(meal.entryList.filter { !$0.isDeleted }, id: \.objectID) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.displayName).foregroundStyle(Theme.textPrimary)
                                Text(Self.amountText(entry))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                NutrientLine(nutrients: entry.total)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                copying = CopyRequest(entries: [entry])
                            } label: {
                                Label("Dä Iitrag kopiere", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    .onDelete(perform: deleteEntries)
                    Button {
                        showsAddFood = true
                    } label: {
                        Label("Meh drzue tue", systemImage: "plus")
                    }
                } header: {
                    Text("Iiträg")
                } footer: {
                    let sum = meal.nutrientSum
                    NutrientLine(nutrients: sum.values, incomplete: sum.incompleteFields)
                }

                Section {
                    Button("Mahlzyt lösche", role: .destructive) { confirmsDelete = true }
                }
            }
            .themedList()
            .navigationTitle(meal.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            copying = CopyRequest(entries: meal.entryList.filter { !$0.isDeleted })
                        } label: {
                            Label("Ganzi Mahlzyt kopiere", systemImage: "doc.on.doc")
                        }
                        Button {
                            sharing = app.store.sharedMeal(from: meal)
                        } label: {
                            Label("Teile", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $copying) { request in
                CopyMealView(
                    entries: request.entries,
                    title: request.entries.count > 1 ? meal.title : nil,
                    category: meal.category,
                    from: meal.timestamp ?? Date()
                )
            }
            .sheet(item: $sharing) { shared in
                ShareMealView(meal: shared)
            }
            .confirmationDialog("Mahlzyt lösche?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Lösche", role: .destructive) {
                    app.store.deleteMeal(meal)
                    app.dataDidChange()
                    dismiss()
                }
            }
            .sheet(item: $editingEntry) { entry in
                entryEditor(entry)
            }
            .sheet(isPresented: $showsAddFood) {
                AddFoodView(existingMeal: meal)
            }
        }
    }

    /// Hülle, damit die Kopierauswahl als `sheet(item:)` aufgehen kann.
    struct CopyRequest: Identifiable {
        let id = UUID()
        let entries: [FoodEntry]
    }

    static func amountText(_ entry: FoodEntry) -> String {
        switch entry.kind {
        case .quick:
            return "Schnäll-Iitrag"
        case .recipe:
            return "\(NumberText.amount(entry.servings)) \(entry.servings == 1 ? "Portion" : "Portione")"
        case .product, .external:
            let unit = entry.isLiquid ? "ml" : "g"
            let label = entry.unitLabel ?? unit
            if label == unit {
                return "\(NumberText.amount(entry.grams)) \(unit)"
            }
            return "\(NumberText.amount(entry.amount)) × \(label) (\(NumberText.amount(entry.grams)) \(unit))"
        }
    }

    // MARK: - Eintrag bearbeiten

    @ViewBuilder
    private func entryEditor(_ entry: FoodEntry) -> some View {
        switch entry.kind {
        case .quick:
            QuickEntryView(initial: BasketItem(
                id: entry.id ?? UUID(), name: entry.displayName, count: 1,
                portion: PortionChoice(name: nil, gramsPerUnit: 1), isLiquid: false,
                per100: nil, fixedTotal: entry.total, kind: .quick, sourceId: nil
            )) { updated in
                entry.name = updated.name
                entry.total = updated.total
                changed()
            }
        case .recipe:
            let perServing = entry.servings > 0 ? entry.total.scaled(by: 1 / entry.servings) : entry.total
            AmountPickerView(
                title: entry.displayName, isLiquid: false, isRecipe: true, per100: perServing, portions: [],
                initialPortion: PortionChoice(name: "Portion", gramsPerUnit: 100), initialCount: entry.servings,
                confirmTitle: "Übernäh"
            ) { _, count in
                entry.servings = count
                entry.amount = count
                entry.total = perServing.scaled(by: count)
                changed()
            }
        case .product, .external:
            let per100 = entry.grams > 0 ? entry.total.scaled(by: 100 / entry.grams) : entry.total
            let portions = portionChoices(for: entry)
            let current = portions.first { ($0.name ?? "") == (entry.unitLabel ?? "") && $0.name != nil }
                ?? PortionChoice(name: nil, gramsPerUnit: 1)
            VStack(spacing: 0) {
                AmountPickerView(
                    title: entry.displayName, isLiquid: entry.isLiquid, per100: per100, portions: portions,
                    initialPortion: current, initialCount: current.name == nil ? entry.grams : entry.amount,
                    confirmTitle: "Übernäh"
                ) { portion, count in
                    entry.amount = count
                    entry.unitLabel = portion.name ?? (entry.isLiquid ? "ml" : "g")
                    entry.grams = portion.grams(for: count)
                    entry.total = per100.forAmount(entry.grams)
                    changed()
                }
                if let product = linkedProduct(entry) {
                    Button {
                        entry.total = product.per100.forAmount(entry.grams)
                        changed()
                        editingEntry = nil
                    } label: {
                        Label("Wärt vom Produkt nöi lade", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .background(Theme.background)
                }
            }
        }
    }

    private func linkedProduct(_ entry: FoodEntry) -> FoodProduct? {
        guard entry.kind == .product, let sourceId = entry.sourceId, let id = UUID(uuidString: sourceId) else { return nil }
        return app.store.object(FoodProduct.self, id: id)
    }

    private func portionChoices(for entry: FoodEntry) -> [PortionChoice] {
        linkedProduct(entry)?.portionChoices ?? [PortionChoice(name: nil, gramsPerUnit: 1)]
    }

    private func deleteEntries(at offsets: IndexSet) {
        let entries = meal.entryList.filter { !$0.isDeleted }
        let doomed = offsets.map { entries[$0] }
        let deletesMeal = doomed.count == entries.count
        doomed.forEach { app.store.deleteEntry($0) }
        app.dataDidChange()
        if deletesMeal { dismiss() }
    }

    private func changed() {
        app.store.mealDidChange(meal)
        app.dataDidChange()
    }
}
