import CoreData
import SwiftUI

/// Apple Health: Status, Berechtigung, was gelesen und geschrieben wird.
struct HealthSettingsView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                LabeledValueRow(label: "Health uf däm Grät") {
                    Text(app.health.isAvailable ? "Verfüegbar" : "Nid verfüegbar")
                        .foregroundStyle(app.health.isAvailable ? Theme.good : Theme.bad)
                }
                Button("Berächtigunge aafrage") {
                    Task {
                        let granted = await app.health.requestAuthorization()
                        message = granted
                            ? "Erledigt. Was du erloubt hesch, gseht buschper jetz."
                            : "Health isch nid verfüegbar oder d Aafrag isch abbroche."
                        await app.healthSync.processPending()
                    }
                }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            } footer: {
                Text("iOS zeigt dr Dialog nume bim erste Mal. Speter änderisch d Berächtigunge i dr Health-App: Profilbild obe rächts → Apps → buschper.")
            }

            Section("Läse") {
                Label("Aktivkalorie, Schritt, Trainingsminute", systemImage: "figure.walk")
                Label("Trainings vo dr Uhr u angere Apps", systemImage: "figure.run")
                Label("Gwicht, Grössi, Geburtsdatum, Gschlächt", systemImage: "scalemass.fill")
                Label("Schlaf mit Phase", systemImage: "moon.zzz.fill")
            }

            Section {
                Label("Mahlzyte mit Nährwärt", systemImage: "fork.knife")
                Label("Wasser", systemImage: "drop.fill")
                Label("Gwicht, wo du vo Hand erfasst", systemImage: "scalemass")
                Label("Trainings, wo du vo Hand erfasst", systemImage: "figure.run")
            } header: {
                Text("Schrybe")
            } footer: {
                Text("Gschribe wird nume uf em Grät, wo dr Iitrag erfasst worde isch – Health glycht säuber zwüsche dyne Grät ab. Ernährigsdate vo angere Apps list buschper nid, süsch würd doppelt zellt.")
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Apple Health")
    }
}

/// Lebensmittelquellen und der Schalter für Open Food Facts.
struct FoodSourcesSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        Form {
            Section {
                Toggle("Open Food Facts frage", isOn: Binding(
                    get: { preferences.usesOpenFoodFacts },
                    set: { preferences.usesOpenFoodFacts = $0 }
                ))
            } footer: {
                Text("Bi Suechi u Barcode fragt buschper d offeni Datebank Open Food Facts – übertrage wird nume dr Suechbegriff oder dr Barcode. Ohni das blybe dyni eigete Produkt u d Schwiizer Nährwärtdatebank, beidi ohni Netz.")
            }
            Section("Reihefolg bi dr Suechi") {
                Label("Eigeti Produkt", systemImage: "1.circle.fill")
                Label("Favorite u zletscht bruucht", systemImage: "2.circle.fill")
                Label("Rezept", systemImage: "3.circle.fill")
                Label("Schwiizer Nährwärtdatebank (BLV)", systemImage: "4.circle.fill")
                Label("Open Food Facts", systemImage: "5.circle.fill")
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Datebanke")
    }
}

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledValueRow(label: "Version") { Text(version).monospacedDigit() }
            }
            Section("Quelle") {
                Text("Nährwärt vo Grundnahrigsmittel: Schwiizer Nährwärtdatebank, Bundesamt für Lebensmittelsicherheit u Veterinärwäse (BLV), naehrwertdaten.ch")
                Text("Verpackti Produkt: Open Food Facts, openfoodfacts.org, Lizänz ODbL")
                Text("MET-Wärt für Trainings: Compendium of Physical Activities")
            }
            .font(.footnote)
            Section("Hiwis") {
                Text("buschper isch kes Medizinprodukt. D Schlafuswärtig zeigt statistischi Zämehäng i dyne eigete Date, kener Diagnose.")
                    .font(.footnote)
            }
            Section("Dateschutz") {
                Text("Aui Date blybe uf dym Grät, i dym private iCloud-Bereich u – we du's erloubsch – i Apple Health. buschper het ke eigete Server u kener Tracker.")
                    .font(.footnote)
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Über buschper")
    }
}

#if DEBUG
/// Nur in Debug-Builds sichtbar (SETUP.md, Abschnitt 7).
struct DeveloperSection: View {
    @Environment(AppEnvironment.self) private var app
    @State private var message: String?

    var body: some View {
        Section {
            Button("CloudKit-Schema anlegen") {
                do {
                    try app.persistence.initializeCloudKitSchema()
                    message = "Schema angelegt. Kontrolle im CloudKit-Dashboard."
                } catch {
                    message = "Fehler: \(error.localizedDescription)"
                }
            }
            Button("Ersteinrichtung neu starten") {
                app.store.profile().onboardingCompleted = false
                app.dataDidChange()
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        } header: {
            Text("Entwicklung")
        }
    }
}
#endif
