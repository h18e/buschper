import SwiftUI

// Platzhalter für Schritt 1. Sie werden in den folgenden Schritten durch die
// richtigen Bildschirme ersetzt und verschwinden dann.

struct TodayPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(DashboardCard.allCases) { card in
                        CardHeader(title: card.label, subtitle: "Chunnt bau", symbol: card.symbolName, color: card.color)
                            .card(tint: card.color)
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Hüt")
        }
    }
}

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

