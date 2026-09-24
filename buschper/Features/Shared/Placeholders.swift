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

struct MePlaceholderView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(symbol: "person.crop.circle.fill", title: "Ig", message: "Chunnt i Schritt 2.")
                .frame(maxHeight: .infinity)
                .screenBackground()
                .navigationTitle("Ig")
        }
    }
}

struct QuickAddPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Erfasse")
                .font(.headline)
            HStack(spacing: 12) {
                placeholderButton("Ässe", "fork.knife", Theme.nutrition)
                placeholderButton("Trinke", "drop.fill", Theme.fluid)
                placeholderButton("Gwicht", "scalemass.fill", Theme.weight)
                placeholderButton("Training", "figure.run", Theme.activity)
            }
            Text("D Erfassig chunnt i de Schritte 3 u 4.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }

    private func placeholderButton(_ title: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.background)
                .frame(width: 56, height: 56)
                .background(color, in: Circle())
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
