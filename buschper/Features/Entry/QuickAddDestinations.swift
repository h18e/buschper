import SwiftUI

/// Ziele der Schnellerfassung, die in Schritt 4 dazukommen.
enum QuickAddDestinations {
    @ViewBuilder
    static func drink() -> some View {
        EmptyStateView(symbol: "drop.fill", title: "Trinke", message: "Chunnt i Schritt 4.")
            .screenBackground()
    }

    @ViewBuilder
    static func weight() -> some View {
        EmptyStateView(symbol: "scalemass.fill", title: "Gwicht", message: "Chunnt i Schritt 4.")
            .screenBackground()
    }

    @ViewBuilder
    static func workout() -> some View {
        EmptyStateView(symbol: "figure.run", title: "Training", message: "Chunnt i Schritt 4.")
            .screenBackground()
    }
}
