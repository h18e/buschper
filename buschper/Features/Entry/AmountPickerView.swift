import CoreData
import SwiftUI

/// Menge wählen: Gramm/ml oder eine Portionsgrösse, mit Vorschau der Nährwerte.
struct AmountPickerView: View {
    let title: String
    let subtitle: String?
    let isLiquid: Bool
    let isRecipe: Bool
    /// Pro 100 g/ml, bei Rezepten pro Portion.
    let per100: Nutrients
    let portions: [PortionChoice]
    var confirmTitle = "Is Chörbli"
    let onConfirm: (PortionChoice, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var portion: PortionChoice
    @State private var count: Double

    init(
        title: String,
        subtitle: String? = nil,
        isLiquid: Bool,
        isRecipe: Bool = false,
        per100: Nutrients,
        portions: [PortionChoice],
        initialPortion: PortionChoice,
        initialCount: Double,
        confirmTitle: String = "Is Chörbli",
        onConfirm: @escaping (PortionChoice, Double) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isLiquid = isLiquid
        self.isRecipe = isRecipe
        self.per100 = per100
        self.portions = portions
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        _portion = State(initialValue: initialPortion)
        _count = State(initialValue: initialCount)
    }

    /// Kandidat aus der Suche: vorgeschlagene Menge ist eine Portion oder 100 g.
    init(candidate: FoodCandidate, onConfirm: @escaping (PortionChoice, Double) -> Void) {
        let choice = candidate.defaultChoice
        self.init(
            title: candidate.name,
            subtitle: [candidate.brand, candidate.sourceLabel].compactMap { $0 }.joined(separator: " · "),
            isLiquid: candidate.isLiquid,
            isRecipe: candidate.isRecipe,
            per100: candidate.per100,
            portions: candidate.portions,
            initialPortion: choice.portion,
            initialCount: choice.count,
            onConfirm: onConfirm
        )
    }

    private var unit: String {
        if isRecipe { return "Portione" }
        return portion.name ?? (isLiquid ? "ml" : "g")
    }

    private var total: Nutrients {
        per100.forAmount(portion.grams(for: count))
    }

    private var quickCounts: [Double] {
        if isRecipe || portion.name != nil { return [0.5, 1, 1.5, 2] }
        return isLiquid ? [100, 200, 250, 330, 500] : [50, 100, 150, 200, 250]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if !isRecipe && portions.count > 1 {
                        Picker("Einheit", selection: $portion) {
                            ForEach(portions, id: \.self) { choice in
                                Text(choice.name.map { "\($0) (\(NumberText.amount(choice.gramsPerUnit)) \(isLiquid ? "ml" : "g"))" }
                                     ?? (isLiquid ? "Milliliter" : "Gramm"))
                                    .tag(choice)
                            }
                        }
                        .onChange(of: portion) { _, newValue in
                            count = newValue.name == nil ? 100 : 1
                        }
                    }
                    NumberField(title: "Mängi", value: $count, unit: unit, fractionDigits: 2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(quickCounts, id: \.self) { value in
                                Button(NumberText.amount(value)) { count = value }
                                    .buttonStyle(.bordered)
                                    .tint(count == value ? Theme.accent : Theme.textSecondary)
                            }
                        }
                    }
                }

                Section {
                    NutrientTable(nutrients: total)
                } header: {
                    Text(isRecipe ? "Nährwärt" : "Nährwärt für \(NumberText.amount(portion.grams(for: count))) \(isLiquid ? "ml" : "g")")
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
                    Button(confirmTitle) {
                        onConfirm(portion, count)
                        dismiss()
                    }
                    .disabled(count <= 0)
                }
            }
        }
    }
}

/// Schnell-Iitrag für ein ganzes Gericht (SPEC 5.6). Wird nicht als Produkt
/// gespeichert, sondern lebt nur in der Mahlzeit.
struct QuickEntryView: View {
    var initial: BasketItem?
    let onConfirm: (BasketItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcalOnly = false
    @State private var carbs: Double?
    @State private var protein: Double?
    @State private var fat: Double?
    @State private var fiber: Double?
    @State private var alcohol: Double?
    @State private var kcal: Double?
    @State private var loaded = false

    private var item: BasketItem {
        BasketItem.quick(
            name: name,
            carbs: carbs, protein: protein, fat: fat, fiber: fiber, alcohol: alcohol,
            kcalOnly: kcalOnly ? kcal : nil
        )
    }

    private var isValid: Bool {
        kcalOnly ? (kcal ?? 0) > 0 : ((carbs ?? 0) + (protein ?? 0) + (fat ?? 0) + (alcohol ?? 0)) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Pasta Kantine", text: $name)
                    Picker("Aagabe", selection: $kcalOnly) {
                        Text("Makros").tag(false)
                        Text("Nume kcal").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                if kcalOnly {
                    Section {
                        OptionalNumberField(title: "Energie", value: $kcal, unit: "kcal", fractionDigits: 0)
                    }
                } else {
                    Section {
                        OptionalNumberField(title: "Kohlehydrat", value: $carbs, unit: "g")
                        OptionalNumberField(title: "Eiwiss", value: $protein, unit: "g")
                        OptionalNumberField(title: "Fett", value: $fat, unit: "g")
                        OptionalNumberField(title: "Ballaststoffe", value: $fiber, unit: "g")
                        OptionalNumberField(title: "Alkohol", value: $alcohol, unit: "g")
                    } footer: {
                        Text("Energie wird usgrächnet: \(NumberText.kcal(item.total.kcal ?? 0)) kcal (4 kcal pro g KH u Eiwiss, 9 pro g Fett, 7 pro g Alkohol).")
                    }
                }
                Section {
                    Text("Dä Iitrag wird nume i dr Mahlzyt gspycheret, nid als eigets Produkt.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .themedList()
            .navigationTitle("Schnäll-Iitrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernäh") {
                        var result = item
                        if let initial { result.id = initial.id }
                        onConfirm(result)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let initial, let total = initial.fixedTotal else { return }
        name = initial.name
        let hasMacros = total.carbs != nil || total.protein != nil || total.fat != nil
        kcalOnly = !hasMacros
        carbs = total.carbs
        protein = total.protein
        fat = total.fat
        fiber = total.fiber
        alcohol = total.alcohol
        kcal = total.kcal
    }
}
