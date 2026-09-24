import CoreData
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

/// Weitere Einstellungen: Erinnerungen, Export.
struct MeSettingsExtraRows: View {
    var body: some View {
        NavigationLink {
            ReminderSettingsView()
        } label: {
            Label("Erinnerige", systemImage: "bell.fill")
        }
        NavigationLink {
            ExportView()
        } label: {
            Label("Date exportiere", systemImage: "square.and.arrow.up")
        }
    }
}
