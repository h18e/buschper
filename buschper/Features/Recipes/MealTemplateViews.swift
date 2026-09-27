import CoreData
import SwiftUI

/// Gespeicherte ganze Mahlzeiten verwalten (SPEC 5.10). Erfasst werden sie in „Ässe“.
struct MealTemplatesView: View {
    @Environment(AppEnvironment.self) private var app
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], predicate: RecipeKind.mealsOnly)
    private var templates: FetchedResults<Recipe>

    var body: some View {
        List {
            if templates.isEmpty {
                EmptyStateView(
                    symbol: "fork.knife",
                    title: "No kener Mahlzyte",
                    message: "I „Ässe“ bi „Ganzi Mahlzyt“ dr Schauter „Für speter spychere“ ischaute – oder im Chörbli „Chörbli als Mahlzyt spychere“ tippe."
                )
                .listRowBackground(Color.clear)
            }
            ForEach(templates, id: \.objectID) { template in
                NavigationLink {
                    MealTemplateDetailView(template: template)
                } label: {
                    MealTemplateRow(template: template)
                }
            }
            .onDelete { offsets in
                offsets.map { templates[$0] }.forEach(app.store.deleteRecipe)
            }
        }
        .themedList()
        .navigationTitle("Mahlzyte")
    }
}

/// Inhalt einer gespeicherten Mahlzeit; der Name lässt sich ändern.
struct MealTemplateDetailView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var template: Recipe
    @State private var name = ""

    var body: some View {
        List {
            Section("Name") {
                TextField("Name", text: $name)
                    .onSubmit(rename)
            }
            Section {
                ForEach(template.ingredientList, id: \.objectID) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name ?? "").foregroundStyle(Theme.textPrimary)
                        Text(amountText(item)).font(.caption).foregroundStyle(Theme.textSecondary)
                        NutrientLine(nutrients: item.per100.forAmount(item.amountG))
                    }
                }
            } header: {
                Text("Inhalt")
            } footer: {
                NutrientLine(nutrients: template.totalNutrients)
            }
            Section {
                Button("Mahlzyt lösche", role: .destructive) {
                    app.store.deleteRecipe(template)
                    dismiss()
                }
            }
        }
        .themedList()
        .navigationTitle(template.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = template.name ?? "" }
        .onDisappear(perform: rename)
    }

    private func rename() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isDeleted, template.managedObjectContext != nil,
              !trimmed.isEmpty, trimmed != template.name else { return }
        template.name = trimmed
        template.updatedAt = Date()
        app.store.save()
    }

    private func amountText(_ item: RecipeIngredient) -> String {
        switch FoodEntryKind(rawValue: item.sourceKindRaw ?? "") ?? .external {
        case .quick:
            return "Ganzi Mahlzyt"
        case .recipe:
            let servings = item.amountG / 100
            return "\(NumberText.amount(servings)) \(servings == 1 ? "Portion" : "Portione")"
        case .product, .external:
            return item.isLiquid ? NumberText.volume(item.amountG) : "\(NumberText.amount(item.amountG)) g"
        }
    }
}
