import SwiftUI

/// Rezepte verwalten (SPEC 5.7).
struct RecipeListView: View {
    @Environment(AppEnvironment.self) private var app
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var recipes: FetchedResults<Recipe>

    @State private var editing: Recipe?
    @State private var creating = false

    var body: some View {
        List {
            if recipes.isEmpty {
                EmptyStateView(
                    symbol: "book.closed",
                    title: "No kener Rezept",
                    message: "E Rezept het Zuetate mit Mängi u e Aazau Portione. Erfasst wird's speter i Portione.",
                    actionTitle: "Nöis Rezept"
                ) { creating = true }
                .listRowBackground(Color.clear)
            }
            ForEach(recipes) { recipe in
                Button {
                    editing = recipe
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recipe.displayName).foregroundStyle(Theme.textPrimary)
                            Text("\(recipe.ingredientList.count) Zuetate · \(NumberText.amount(recipe.servings)) Portione")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                        if recipe.isFavorite {
                            Image(systemName: "star.fill").foregroundStyle(Theme.warning)
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(NumberText.kcal(recipe.perServing.kcal ?? 0)) kcal")
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(Theme.nutrition)
                            Text("pro Portion").font(.caption2).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button {
                        recipe.isFavorite.toggle()
                        app.dataDidChange()
                    } label: {
                        Label("Favorit", systemImage: "star")
                    }
                    .tint(Theme.warning)
                }
            }
            .onDelete { offsets in
                offsets.map { recipes[$0] }.forEach(app.store.deleteRecipe)
                app.dataDidChange()
            }
        }
        .themedList()
        .navigationTitle("Rezept")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { recipe in
            RecipeEditorView(existing: recipe)
        }
        .sheet(isPresented: $creating) {
            RecipeEditorView()
        }
    }
}

struct RecipeEditorView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let existing: Recipe?
    @State private var draft: RecipeDraft
    @State private var addingIngredient = false
    @State private var editingIngredient: RecipeDraft.Ingredient?
    @State private var confirmsDelete = false

    init(existing: Recipe? = nil, draft: RecipeDraft = RecipeDraft()) {
        self.existing = existing
        _draft = State(initialValue: existing.map(RecipeDraft.init(recipe:)) ?? draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Lasagne", text: $draft.name)
                    Stepper(value: $draft.servings, in: 1...40, step: 1) {
                        LabeledValueRow(label: "Portione") {
                            Text(NumberText.amount(draft.servings)).monospacedDigit()
                        }
                    }
                }

                Section {
                    ForEach(draft.ingredients) { ingredient in
                        Button {
                            editingIngredient = ingredient
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ingredient.name).foregroundStyle(Theme.textPrimary)
                                    Text("\(NumberText.amount(ingredient.amountG)) \(ingredient.isLiquid ? "ml" : "g")")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Text("\(NumberText.kcal(ingredient.total.kcal ?? 0)) kcal")
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { draft.ingredients.remove(atOffsets: $0) }
                    .onMove { draft.ingredients.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        addingIngredient = true
                    } label: {
                        Label("Zuetat drzue", systemImage: "plus")
                    }
                } header: {
                    Text("Zuetate")
                }

                if !draft.ingredients.isEmpty {
                    Section {
                        NutrientTable(nutrients: draft.perServing)
                    } header: {
                        Text("Pro Portion")
                    } footer: {
                        Text("Total \(NumberText.kcal(draft.total.kcal ?? 0)) kcal für \(NumberText.amount(draft.servings)) Portione.")
                    }
                }

                Section {
                    TextField("Notiz", text: $draft.note, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let existing {
                    Section {
                        Button("Rezept lösche", role: .destructive) { confirmsDelete = true }
                    } footer: {
                        Text("Scho erfassti Mahlzyte blybe, wie si sy.")
                    }
                    .confirmationDialog("Rezept lösche?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                        Button("Lösche", role: .destructive) {
                            app.store.deleteRecipe(existing)
                            app.dataDidChange()
                            dismiss()
                        }
                    }
                }
            }
            .themedList()
            .navigationTitle(existing == nil ? "Nöis Rezept" : "Rezept")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") {
                        app.store.saveRecipe(draft, editing: existing)
                        app.dataDidChange()
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
            .sheet(isPresented: $addingIngredient) {
                IngredientPickerView { draft.ingredients.append($0) }
            }
            .sheet(item: $editingIngredient) { ingredient in
                AmountPickerView(
                    title: ingredient.name,
                    isLiquid: ingredient.isLiquid,
                    per100: ingredient.per100,
                    portions: [PortionChoice(name: nil, gramsPerUnit: 1)],
                    initialPortion: PortionChoice(name: nil, gramsPerUnit: 1),
                    initialCount: ingredient.amountG,
                    confirmTitle: "Übernäh"
                ) { portion, count in
                    if let index = draft.ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                        draft.ingredients[index].amountG = portion.grams(for: count)
                    }
                }
            }
        }
    }
}
