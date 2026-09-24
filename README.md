# buschper

Persönlicher Gesundheitstracker für iPhone: Ernährung, Trinken, Aktivität, Gewicht
und Schlaf. Dazu eine Schlafanalyse, die nach schlechten Nächten im Vortag nach
Ursachen sucht und über die Zeit Muster erkennt.

- **Spezifikation:** [SPEC.md](SPEC.md) ← aktueller Stand: Entwurf, wartet auf Freigabe
- **Ersteinrichtung:** [SETUP.md](SETUP.md)
- **Vor einer Veröffentlichung:** [RELEASE.md](RELEASE.md)
- **Datenschutz:** [PRIVACY.md](PRIVACY.md)

## Überblick

| | |
|---|---|
| Zielsystem | iOS 26 und neuer |
| Oberfläche | SwiftUI, Swift Charts |
| Daten & Abgleich | Core Data über `NSPersistentCloudKitContainer`, nur private iCloud-Datenbank |
| Gesundheitsdaten | HealthKit, lesen und schreiben |
| Lebensmittel | Eigene Produkte → Schweizer Nährwertdatenbank (offline) → Open Food Facts |
| Barcode | VisionKit, aus Frostify übernommen |
| Teilen | `.buschper`-Datei und QR-Code, ohne Server |
| Erweiterungen | Widget mit „+250 ml“-Knopf |
| Gestaltung | Nur dunkel, jeder Bereich mit eigener Farbe |
| Sprache | Berndeutsch |
| Abhängigkeiten | keine externen Pakete |

## Stand

Die Spezifikation ist geschrieben, der Code folgt nach der Freigabe.
Die Umsetzungsreihenfolge steht in [SPEC.md](SPEC.md), Abschnitt 21.
