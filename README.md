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

## Aufbau

```
buschper/
├── App/              Einstieg, Tabs
├── Domain/           Reine Rechenlogik ohne Core Data, HealthKit und SwiftUI – voll getestet
├── Model/            Core-Data-Modell, Entitäten (generiert), bequeme Zugriffe
├── Persistence/      Core-Data-Stack mit privatem iCloud-Abgleich, im App-Group-Container
├── Health/           Apple Health (ab Schritt 2)
├── Food/             Lebensmittelsuche, BLV, Open Food Facts (ab Schritt 3)
├── Features/         Bildschirme
├── Services/         Gerätelokale Einstellungen, Erinnerungen
├── Theme/            Farben pro Bereich, Karten, Bausteine
└── Resources/        Asset-Katalog
Shared/               Code für App und Widget (Widget-Zusammenfassung)
buschperWidget/       Widget klein und mittel mit „+250 ml“
buschperTests/        Tests der Rechenlogik (Swift Testing)
tools/                Modell-Generator, Strukturprüfung, BLV-Import
Config/               Signing, Entitlements, Info.plist
```

### Schichtenregel

- **Domain** kennt weder Core Data noch HealthKit noch SwiftUI. Alles, was
  gerechnet wird, liegt hier und bekommt Tests.
- **Model** wird aus einer einzigen Definition erzeugt:
  `python3 tools/generate_model.py` schreibt das Core-Data-Modell und die
  `@NSManaged`-Klassen. Bequeme Zugriffe (`meal.category`, `entry.total`) stehen
  getrennt in `Model/EntityExtensions/`.
- **Nährwerte** liegen in Core Data als kompaktes JSON (`nutrientsJSON`). So kann ein
  Wert „unbekannt“ sein, statt stillschweigend 0 – wichtig für ehrliche Summen.

## Widget

Das Widget öffnet die Datenbank **nicht**. Die App legt nach jeder Änderung eine
kleine Zusammenfassung in den App-Group-Bereich (`Shared/WidgetBridge.swift`);
das Widget zeigt sie an. Der Knopf „+250 ml“ legt das Glas in eine Warteschlange
und passt die Anzeige sofort an; die App übernimmt es beim nächsten Öffnen als
richtigen Eintrag und schreibt es nach Health. So schreiben nie zwei Prozesse
gleichzeitig in Core Data und iCloud.

## Farben

Die Bereichsfarben sind mit einem Palette-Prüfer gegen die dunkle Kartenfläche
geprüft: Helligkeit im Band für dunkle Flächen, genug Sättigung, unterscheidbar
auch bei Rot-Grün-Schwäche. Deshalb ist das Rot der Aktivität etwas dunkler und
das Gelb des Gewichts heller als ein „reines“ Rot/Gelb. Farbe steht nie allein:
Karten haben Titel und Symbol, schlechte Nächte im Graphen sind Dreiecke.

## Prüfen ohne Xcode

```bash
python3 tools/verify_structure.py
```

Prüft Klammern aller Swift-Dateien, XML und JSON, die Projektdatei, das
Core-Data-Modell gegen die Klassen, Info.plist, Entitlements und die
Health-Texte. Das ersetzt **keinen** Compiler: den Build-Nachweis liefert Xcode
mit ⌘B, die Tests laufen mit ⌘U.

## Stand

| Schritt | Inhalt | Status |
|---|---|---|
| 1 | Projekt, Theme, Datenmodell, Persistenz, Rechenlogik mit Tests | ✅ |
| 2 | Profil, Ersteinrichtung, Apple Health, Bedarfsberechnung | ✅ |
| 3 | Ernährung: Suche, Produkte, Barcode, BLV, Open Food Facts, Chörbli, Schnell-Iitrag | ✅ |
| 4 | Trinken, Gewicht, Training | ✅ |
| 5 | Dashboard | ✅ |
| 6 | Rezepte, Kopieren, Teilen | ✅ |
| 7 | Schlaf: Score, Tab, Morgen-Einschätzung | ✅ |
| 8 | Schlafanalyse und Muster | ✅ |
| 9 | Widget, Erinnerungen, Export | ✅ |
| 10 | SETUP und RELEASE vervollständigen | |
