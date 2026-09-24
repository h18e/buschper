import SwiftUI

/// Sammlungen im Tab „Ig“: eigene Produkte, Rezepte, Favoriten.
struct MeCollectionsSection: View {
    var body: some View {
        Section("Sammlige") {
            NavigationLink {
                ProductListView()
            } label: {
                Label("Eigeti Produkt", systemImage: "shippingbox.fill")
            }
            MeRecipeRow()
            NavigationLink {
                FavoritesListView()
            } label: {
                Label("Favorite", systemImage: "star.fill")
            }
        }
        .listRowBackground(Theme.surface)
    }
}

struct MeRecipeRow: View {
    var body: some View {
        NavigationLink {
            RecipeListView()
        } label: {
            Label("Rezept", systemImage: "book.closed.fill")
        }
    }
}

/// Weitere Einstellungen: Erinnerungen, Export. Wird in Schritt 9 gefüllt.
struct MeSettingsExtraRows: View {
    var body: some View {
        EmptyView()
    }
}
