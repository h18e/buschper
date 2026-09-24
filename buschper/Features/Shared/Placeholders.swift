import SwiftUI

// Platzhalter für Schritt 1. Sie werden in den folgenden Schritten durch die
// richtigen Bildschirme ersetzt und verschwinden dann.

struct SleepPlaceholderView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(symbol: "moon.zzz.fill", title: "Schlaf", message: "Chunnt i Schritt 7.")
                .frame(maxHeight: .infinity)
                .screenBackground()
                .navigationTitle("Schlaf")
        }
    }
}

