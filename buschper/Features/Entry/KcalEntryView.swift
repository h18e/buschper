import CoreData
import SwiftUI

/// Nur eine Kalorienzahl – ohne Titel und ohne Makros (SPEC 5.6).
///
/// Wird direkt gesichert, ohne Umweg übers Chörbli. Für Fälle, in denen nur die
/// kcal bekannt sind. Im Tagesprotokoll steht der
/// Eintrag als „Kalorie“; Makros bleiben „unbekannt“, nicht 0.
struct KcalEntryView: View {
    /// Wohin gesichert wird, z. B. „als Zmittag um 12:30“.
    var saveHint: String = ""
    let onConfirm: (BasketItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kcal: Double = 0

    static let defaultName = "Kalorie"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AmountInput(
                    value: $kcal,
                    unit: "kcal",
                    sliderMax: 1500,
                    step: 10,
                    quickValues: [100, 200, 300, 500, 800],
                    tint: Theme.nutrition
                )
                Text("\(saveHint) Nume d Energie – Makros blybe läär. Im Tagesprotokoll steit „\(Self.defaultName)“.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding()
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
                        ))
                        dismiss()
                    }
                    .disabled(kcal <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
