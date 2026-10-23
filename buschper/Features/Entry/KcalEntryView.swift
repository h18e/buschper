import CoreData
import SwiftUI

/// Nur eine Kalorienzahl mit Kategorie – ohne Titel und ohne Makros (SPEC 5.6).
///
/// Wird direkt gesichert, ohne Umweg übers Chörbli. Im Tagesprotokoll steht der
/// Eintrag als „Kalorie“; Makros bleiben „unbekannt“, nicht 0.
struct KcalEntryView: View {
    /// Vorschlag aus „Ässe“ (Uhrzeit oder von Hand gewählt).
    let initialCategory: MealCategory
    /// `false`, wenn an eine bestehende Mahlzeit angehängt wird – dann steht
    /// die Kategorie schon fest.
    var choosesCategory = true
    /// Zusatz zum Hinweis je nach gewählter Kategorie, z. B. „um 12:30“ oder
    /// „i „Zmittag““ – geplante Einträge springen auf die feste Zeit.
    var saveHint: (MealCategory) -> String = { _ in "" }
    let onConfirm: (BasketItem, MealCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kcal: Double = 0
    @State private var category: MealCategory?
    @State private var alcohol: Double?
    @State private var caffeine: Double?
    @State private var showsExtras = false

    static let defaultName = "Kalorie"

    private var selected: MealCategory { category ?? initialCategory }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AmountInput(
                        value: $kcal,
                        unit: "kcal",
                        sliderMax: 1500,
                        step: 10,
                        quickValues: [100, 200, 300, 500, 800],
                        tint: Theme.nutrition
                    )
                    if choosesCategory {
                        categoryGrid
                    }
                    extrasBox
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Nume kcal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") {
                        var item = BasketItem.quick(
                            name: Self.defaultName,
                            carbs: nil, protein: nil, fat: nil, fiber: nil, alcohol: nil,
                            kcalOnly: kcal.rounded()
                        )
                        // Zählen nicht zur Energie (die gilt wie eingegeben), aber für den Schlaf.
                        item.fixedTotal?.alcohol = alcohol
                        item.fixedTotal?.caffeine = caffeine
                        onConfirm(item, selected)
                        dismiss()
                    }
                    .disabled(kcal <= 0)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var hint: String {
        let target = choosesCategory ? "als \(selected.label) \(saveHint(selected))" : saveHint(selected)
        return "Wird direkt gspycheret \(target). Nume d Energie – Makros blybe läär. Im Tagesprotokoll steit „\(Self.defaultName)“."
    }

    /// Alkohol und Koffein, fakultativ und eingeklappt.
    private var extrasBox: some View {
        DisclosureGroup("Alkohol u Koffein (fakultativ)", isExpanded: $showsExtras) {
            VStack(spacing: 10) {
                OptionalNumberField(title: "Alkohol", value: $alcohol, unit: "g")
                OptionalNumberField(title: "Koffein", value: $caffeine, unit: "mg", fractionDigits: 0)
                Text("Zellt nid zu de kcal drzue, fliesst aber i d Schlafuswärtig y.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)
        }
        .padding(12)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    /// Sechs Kategorien als Kacheln, zwei Reihen à drei.
    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(MealCategory.allCases) { item in
                let isSelected = item == selected
                Button {
                    category = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbolName)
                            .font(.subheadline)
                        Text(item.label)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
                    .background(
                        isSelected ? Theme.nutrition : Theme.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
