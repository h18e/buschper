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
    /// Zusatz zum Hinweis, z. B. „um 12:30“ oder „i „Zmittag““.
    var saveHint: String = ""
    let onConfirm: (BasketItem, MealCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kcal: Double = 0
    @State private var category: MealCategory?

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
                        onConfirm(BasketItem.quick(
                            name: Self.defaultName,
                            carbs: nil, protein: nil, fat: nil, fiber: nil, alcohol: nil,
                            kcalOnly: kcal.rounded()
                        ), selected)
                        dismiss()
                    }
                    .disabled(kcal <= 0)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var hint: String {
        let target = choosesCategory ? "als \(selected.label) \(saveHint)" : saveHint
        return "Wird direkt gspycheret \(target). Nume d Energie – Makros blybe läär. Im Tagesprotokoll steit „\(Self.defaultName)“."
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
