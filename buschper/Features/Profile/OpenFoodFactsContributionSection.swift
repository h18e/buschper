import CoreData
import SwiftUI

/// Mithelfen bei Open Food Facts – freiwillig und pro Gerät (SPEC 5.11).
/// Jede Person schaltet es auf ihrem iPhone selbst ein und nutzt ihr eigenes Konto.
struct OpenFoodFactsContributionSection: View {
    @EnvironmentObject private var preferences: AppPreferences

    @State private var userId = ""
    @State private var password = ""
    @State private var hasStoredPassword = false
    @State private var loaded = false

    private var canSave: Bool {
        !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
            && !userId.contains("@")
    }

    var body: some View {
        Section {
            Toggle("Open Food Facts mithälfe", isOn: Binding(
                get: { preferences.contributesToOpenFoodFacts },
                set: { preferences.contributesToOpenFoodFacts = $0 }
            ))
            if preferences.contributesToOpenFoodFacts {
                TextField("Benutzername (nid d E-Mail)", text: $userId)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField(hasStoredPassword ? "Passwort (gspycheret)" : "Passwort", text: $password)
                    .textContentType(.password)
                Button("Konto spychere") { saveAccount() }
                    .disabled(!canSave)
                if userId.contains("@") {
                    Text("Bitte dr Benutzername iigäh, nid d E-Mail-Adrässe.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Link(destination: URL(string: "https://world.openfoodfacts.org/cgi/user.pl")!) {
                    Label("Gratis-Konto bi Open Food Facts erstelle", systemImage: "person.badge.plus")
                }
                if hasStoredPassword {
                    Button("Konto vo däm iPhone lösche", role: .destructive) { forgetAccount() }
                }
            }
        } header: {
            Text("Mithälfe")
        } footer: {
            Text("Wenn ygschaltet, fragt buschper bi jedem nöie oder ergänzte Produkt mit Barcode, öb's a Open Food Facts söll. Gschickt wärde nume Barcode, Name, Marke u Nährwärt pro 100 g/ml – nüt über di oder dyni Mahlzyte. D Date sy nachhär öffentlech (Lizänz ODbL). Gilt nume für das iPhone; ds Passwort blybt im Schlüsselbund.")
        }
        .onAppear(perform: load)

        if preferences.contributesToOpenFoodFacts && !preferences.openFoodFactsLastResult.isEmpty {
            Section("Letschte Biitrag") {
                Text(preferences.openFoodFactsLastResult)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        userId = preferences.openFoodFactsUserId
        hasStoredPassword = KeychainStore.password(for: userId) != nil
    }

    private func saveAccount() {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.openFoodFactsUserId = trimmed
        hasStoredPassword = KeychainStore.setPassword(password, for: trimmed)
        password = ""
    }

    private func forgetAccount() {
        KeychainStore.removePasswords()
        preferences.openFoodFactsUserId = ""
        preferences.contributesToOpenFoodFacts = false
        userId = ""
        password = ""
        hasStoredPassword = false
    }
}
