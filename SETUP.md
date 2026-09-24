# buschper einrichten

Schritt für Schritt von „Projekt heruntergeladen“ bis „läuft auf dem iPhone“.
Jeder Schritt nennt den genauen Menüpfad. Wenn etwas nicht so aussieht wie
beschrieben, lieber nachfragen als raten.

**Voraussetzungen:** Mac mit Xcode 26 oder neuer, iPhone mit iOS 26 oder neuer,
Mitgliedschaft im Apple Developer Program (hast du).

> **Stand:** Version 1 ist vollständig umgesetzt (Schritte 1–10). Der Code ist
> ohne Compiler entstanden – beim ersten Bauen sind ein paar Fehler zu erwarten.
> Schick mir dann die vollständigen Fehlertexte (Abschnitt 8).
> Diese Anleitung wächst mit jedem Schritt.

---

## Kurzweg: alles im Terminal

Statt in Xcode zu klicken, erledigt `tools/buschper.sh` die üblichen Schritte.
Einmalig nötig ist nur Abschnitt 1 (Projekt holen) und in Xcode **einmal** das
Apple-Konto unter **Xcode → Settings… (⌘,) → Accounts** – wie bei Frostify, ist
es dort schon drin, ist nichts zu tun.

```bash
cd ~/Developer/buschper
./tools/buschper.sh setup        # Team-ID eintragen, Xcode prüfen (einmalig)
./tools/buschper.sh test         # alle Tests im Simulator
./tools/buschper.sh run          # bauen und im Simulator starten
./tools/buschper.sh device       # auf dem angeschlossenen iPhone starten
./tools/buschper.sh blv ~/Downloads/DATEI.xlsx   # BLV-Datenbank einbauen
./tools/buschper.sh testflight   # neue Version zu TestFlight hochladen
./tools/buschper.sh update       # neuste Version holen (git pull)
```

Geht etwas schief, stehen die vollständigen Fehlertexte in `build/errors.txt`
**und in der Zwischenablage** – einfach mit ⌘V an Claude schicken.

**Nicht im Terminal möglich:** Apple-Konto in Xcode hinterlegen (einmal), am
iPhone „Vertrauen“ und Entwicklermodus bestätigen, die App einmalig in App Store
Connect anlegen und deine Partnerin einladen (Webseite, siehe RELEASE.md), das
App-Icon liefern.

Die Abschnitte unten beschreiben dieselben Schritte ausführlich und in Xcode.

---

## 1. Projekt auf den Mac holen

Zwei gleichwertige Wege – nimm den, bei dem du dich wohler fühlst.

### Weg A: mit Git

Öffne **Terminal** (⌘ + Leertaste, „Terminal“ tippen, Enter):

```bash
mkdir -p ~/Developer          # Ordner "Developer" anlegen, falls es ihn noch nicht gibt
cd ~/Developer                # in diesen Ordner wechseln
git clone https://github.com/h18e/buschper.git
cd buschper
```

Später holst du Änderungen mit:

```bash
cd ~/Developer/buschper
git pull
```

### Weg B: als ZIP

1. https://github.com/h18e/buschper im Browser öffnen
2. Grüner Knopf **Code** → **Download ZIP**
3. ZIP in `~/Developer/` entpacken

> **Wichtig:** Den Projektordner **nicht** in iCloud Drive oder Dropbox legen.
> Cloud-Platzhalterdateien bringen Git und Xcode unbemerkt durcheinander.
> `~/Developer/` ist der richtige Ort.

---

## 2. Team-ID eintragen

Wie bei Frostify liegt dein Entwicklerkonto in einer eigenen, von Git ignorierten
Datei, damit `git pull` nie Konflikte meldet.

Im Terminal, im Projektordner:

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
open -e Config/Signing.local.xcconfig     # öffnet die Datei in TextEdit
```

Ersetze `ABCDE12345` durch deine Team-ID (dieselbe wie bei Frostify) und sichere
mit ⌘S.

**Team-ID finden:** https://developer.apple.com/account → **Membership details** →
Zeile **Team ID**.

---

## 3. Projekt in Xcode öffnen

```bash
open buschper.xcodeproj
```

Beim ersten Öffnen braucht Xcode einen Moment zum Indexieren.

---

## 4. Signing und Capabilities prüfen

1. Im linken Navigator ganz oben auf das blaue Projektsymbol **buschper**
2. In der Spalte **TARGETS** auf **buschper**
3. Reiter **Signing & Capabilities**

| Feld | Erwartet |
|---|---|
| Automatically manage signing | angehakt |
| Team | dein Team (aus Schritt 2) |
| Bundle Identifier | `ch.hebera.buschper` |

Darunter müssen vier Capabilities stehen. Sie kommen aus
`Config/buschper.entitlements`:

| Capability | Inhalt |
|---|---|
| **iCloud** | **CloudKit** angehakt, Container `iCloud.ch.hebera.buschper` |
| **HealthKit** | ohne Häkchen bei „Clinical Health Records“ und „Background Delivery“ |
| **App Groups** | `group.ch.hebera.buschper` |
| **Push Notifications** | – |

**Wenn der iCloud-Container rot ist oder fehlt:** Bei iCloud auf das **+** unter
*Containers* klicken und `iCloud.ch.hebera.buschper` anlegen.

**Wenn die App Group rot ist:** Bei App Groups auf **+** klicken und
`group.ch.hebera.buschper` anlegen. Ohne App Group läuft die App trotzdem; nur das
Widget (kommt in Schritt 9) sieht dann keine Daten.

**Wenn HealthKit fehlt:** Oben links **+ Capability** → „HealthKit“ suchen →
doppelklicken.

**Das Widget ist ein eigenes Target.** In der Spalte **TARGETS** auf
**buschperWidgetExtension** klicken und dort ebenfalls **Signing & Capabilities**
prüfen:

| Feld | Erwartet |
|---|---|
| Team | dein Team (kommt automatisch aus Schritt 2) |
| Bundle Identifier | `ch.hebera.buschper.widget` |
| App Groups | `group.ch.hebera.buschper` angehakt |

---

## 5. Tests laufen lassen

In Xcode: **⌘ + U**

Geprüft wird die gesamte Rechenlogik: Kalorienbedarf, Makros, Flüssigkeitsziel,
Alkohol, Mahlzeit-Kategorien, Schlafscore, schlechte Nächte, Schlaf-Faktoren,
Muster, Aktivitätsstufen, MET-Schätzung, Gewicht, Rezepte, das Teilen-Format,
CSV und die Dashboard-Anordnung. Alle Tests müssen grün sein.

Die Testübersicht findest du mit **⌘ + 6** (Test Navigator).

---

## 6. Erster Start im Simulator

1. Oben in der Leiste ein iPhone-Modell wählen (z. B. „iPhone 17 Pro“)
2. **⌘ + R**

**Erwartung:** Die App startet dunkel mit der **Ersteinrichtung**:

1. „Grüessech bi buschper“ → **Los**
2. „Apple Health“ → **Mit Health verbinde** → iOS zeigt den Health-Dialog →
   **Alle aktivieren** → **Zulassen**
3. „Über di“ – im Simulator ist Health leer, also selbst ausfüllen
4. „Dys Ziel“ → Ziel, Abschlag, Bewegungsprofil, Schlaf- und Schrittziel
5. „Parat!“ → **Fertig**

Danach: Tab **Ig** zeigt oben „Bedarf hüt“ mit Grundumsatz, Aktivkalorien,
Abschlag und Budget. Darunter lassen sich Profil, Ziel, Makros und Tagesziele
ändern – die Zahlen oben passen sich an.

**Im Simulator** gibt es keine Aktivdaten. Vor 12:00 steht bei den Aktivkalorien
0, ab 12:00 „Aktivkalorie (Schätzig)“ aus dem Bewegungsprofil. So ist es gewollt.

**Auf dem iPhone** kommen Aktivkalorien, Gewicht und Profil aus Health. Die
Ersteinrichtung füllt Geburtsdatum, Geschlecht, Grösse und Gewicht vor, wenn sie
dort hinterlegt sind.

**Ernährung testen:** Tab **Erfasse** (＋) → **Ässe**:

| Test | Erwartung |
|---|---|
| „apf“ ins Suchfeld | „Apfel“ aus den Grundnahrungsmitteln, darunter Open Food Facts |
| Treffer antippen → Menge → **Is Chörbli** | Unten erscheint das Chörbli mit kcal |
| **Schnäll-Iitrag** → Makros eingeben | kcal werden live berechnet |
| **Nöis Produkt** → Portionsgrösse „Schiibe = 40 g“ | Danach lässt sich „2 × Schiibe“ wählen |
| **Barcode** (im Simulator: Code eintippen, z. B. `7610200337477`) | Open Food Facts liefert das Produkt, oder das Formular „Nöis Produkt“ geht auf |
| Lange auf einen fremden Treffer drücken → **Korrigiere** | Eigene Kopie; beim nächsten Scan gewinnt sie |
| Stern antippen | Erscheint unter „Favorite“ und in **Ig → Sammlige → Favorite** |
| **Sichere** | Die Mahlzeit ist gespeichert (sichtbar ab Schritt 5 auf „Hüt“) |

**Trinken, Gewicht, Training testen:** ebenfalls über **Erfasse** (＋):

| Test | Erwartung |
|---|---|
| **Trinke** → Bier → 5 dl | Unten: „Zellt nid zur Flüssigkeit · 213 kcal · 19.7 g Alkohol“ |
| **Trinke** → Kafi → **Als Vorlag spychere** | Beim nächsten Mal oben unter „Vorlage“ |
| **Gwicht** → ±0.1-Knöpfe → **Sichere** | Wird auch in Apple Health gespeichert |
| **Training** → Jogge, 45 min, mittu | kcal werden aus deinem Gewicht geschätzt |

In Apple Health (auf dem iPhone) erscheinen die Einträge unter der Quelle
„buschper“: **Health → Profilbild → Apps → buschper → Daten anzeigen**.

**Dashboard testen:** Tab **Hüt**:

| Test | Erwartung |
|---|---|
| Nach dem Erfassen einer Mahlzeit | „No übrig“ sinkt, KH/Eiwiss/Fett/Fasere füllen sich, die Mahlzeit steht in der Tagesliste |
| Mahlzeit in der Tagesliste antippen | Bearbeiten: Zeit, Kategorie, Mengen, löschen |
| **+250 ml Wasser** | Eine Flasche füllt sich, der Balken von heute wächst |
| Flüssigkeitskarte antippen | Alle Getränke des Tages, wischen zum Löschen |
| ◀ / ▶ oder über das Datum wischen | Anderer Tag; Tipp aufs Datum springt zu heute |
| **Wuche / Monet / 3 Mönet** | Alle Graphen wechseln den Zeitraum |
| Im Graphen antippen oder ziehen | Hinweis mit Datum und Wert |
| Oben rechts ⚙︎ (Schieberegler) | Karten ein-/ausblenden und mit den drei Strichen verschieben |

**Rezepte, Kopieren, Teilen testen:**

| Test | Erwartung |
|---|---|
| **Ig → Sammlige → Rezept → +**, Zutaten suchen, 4 Portionen | Nährwerte pro Portion unten |
| **Ässe** → Rezept suchen → 1.5 Portionen | Rezept erscheint in der Mahlzeit als „1.5 Portione“ |
| Mahlzeit öffnen → ⋯ → **Ganzi Mahlzyt kopiere** | Vorschlag: gleiche Zeit am nächsten Tag (nie in der Zukunft) |
| Lange auf einen Eintrag drücken → **Dä Iitrag kopiere** | Nur dieser Eintrag wird kopiert |
| **Ässe** am nächsten Tag, gleiche Kategorie | Oben „Wie geschter: Zmittag“ – ein Tipp legt alles ins Chörbli |
| Mahlzeit → ⋯ → **Teile** | QR-Code und „Als Datei schicke“ |
| QR-Code mit der normalen Kamera eines zweiten iPhones scannen | buschper öffnet sich mit „Mahlzyt übernäh“ |
| Datei per WhatsApp schicken, beim Empfänger antippen → Teilen → buschper | Ebenfalls „Mahlzyt übernäh“ |

**Schlaf testen – nur auf dem iPhone sinnvoll** (der Simulator hat keine
Schlafdaten; man könnte sie in der Health-App des Simulators von Hand eintragen):

| Test | Erwartung |
|---|---|
| Tab **Schlaf** zum ersten Mal öffnen | Die letzten 30 Nächte werden ausgewertet (Fortschrittsrad oben rechts) |
| „Letschti Nacht“ | Score, Schlafzeit, Phasenbalken, Sterne für die Morgen-Einschätzung |
| 1 oder 2 Sterne vergeben | Die Nacht wird als „Schlächti Nacht“ markiert |
| Nacht in der Liste antippen | Zusammensetzung des Scores, Auffälliges am Vortag, Vortag in Zahlen, Notiz, Marken, Ausschluss |
| **Muster** | Erst „No z'weni Date“ – nach einigen Wochen erscheinen Zusammenhänge |
| **Muster → Schwälle aapasse** | Grenzen ändern, dann „Übernäh u aui Nächt nöi uswärte“ |
| ↻ oben rechts | Die letzten 90 Nächte neu auswerten |

**Widget, Erinnerungen, Export testen:**

| Test | Erwartung |
|---|---|
| Homescreen lange drücken → **+** → „buschper“ → klein und mittel | „No übrig … kcal“ und Flüssigkeit |
| Im mittleren Widget **+250 ml** | Die Anzeige springt sofort; beim nächsten Öffnen von buschper steht das Glas in der Liste und in Health |
| **Ig → Erinnerige** → Trink-Erinnerig ein | iOS fragt einmal nach Mitteilungen; Erinnerungen kommen zur vollen Stunde, heute nur bis das Ziel erreicht ist |
| Morge-Iischätzig ein, Mitteilung antippen | buschper öffnet den Tab „Schlaf“ |
| **Ig → Date exportiere** → Dateie erstelle → Teile | Fünf CSV-Dateien; in Excel öffnen |

Voraussetzung für Schlafphasen: Apple Watch in der Nacht tragen, Schlaf-Fokus
mit Schlafplan aktiv. Ohne Uhr kommt nur die Schlafdauer vom iPhone; der Score
rechnet dann ohne Tief- und REM-Schlaf.

**Erwartungsmanagement:** Der Code wurde ohne Compiler geschrieben. Ein paar
Fehler beim ersten Bauen sind gut möglich. Schick mir den vollständigen
Fehlertext (Abschnitt 8).

---

## 7. CloudKit-Schema anlegen

Die Datenbankstruktur in iCloud entsteht nicht von selbst. Einmalig:

1. App im Simulator oder auf dem iPhone starten, Ersteinrichtung abschliessen
2. Tab **Ig** → ganz unten Abschnitt **Entwicklung**
3. **CloudKit-Schema anlegen** antippen

Kontrolle: https://icloud.developer.apple.com/dashboard → Container
`iCloud.ch.hebera.buschper` → **Schema → Record Types**. Dort müssen Typen wie
`CD_Profile`, `CD_Meal`, `CD_FoodEntry` und `CD_NightRecord` auftauchen.

> Der Abschnitt **Entwicklung** erscheint nur in Debug-Builds. Dort gibt es auch
> **Ersteinrichtung neu starten**, falls du sie nochmals durchspielen willst.

---

## 7b. Schweizer Nährwertdatenbank einbauen (einmalig, empfohlen)

buschper bringt vorerst rund 110 Grundnahrungsmittel mit **Richtwerten** mit.
Die vollständige Schweizer Nährwertdatenbank des BLV (über 1'000 Lebensmittel)
konnte ich nicht selbst herunterladen – die Seite ist aus meiner Umgebung
gesperrt. So baust du sie ein:

1. https://naehrwertdaten.ch öffnen → **Downloads** → die Datenbank als
   **Excel (.xlsx)** herunterladen (landet in „Downloads“)
2. Im Terminal:

   ```bash
   cd ~/Developer/buschper
   python3 tools/import_blv.py ~/Downloads/DATEINAME.xlsx
   ```

   `DATEINAME` durch den echten Namen ersetzen – tippe `~/Downloads/` und
   drücke die Tabulatortaste, dann ergänzt das Terminal den Namen.
3. Das Skript zeigt, welche Spalten es erkannt hat, und schreibt
   `buschper/Resources/blv_foods.json`
4. In Xcode **⌘ + R** – die Suche kommt jetzt aus der BLV-Datenbank, und die
   Überschrift heisst „Schwiizer Nährwärtdatebank“

Meldet das Skript fehlende Spalten, schick mir die ganze Ausgabe.

Die Datei `blv_foods.json` bitte **nicht** selbst committen – schick mir einfach
Bescheid, dann nehme ich sie beim nächsten Mal auf. (Oder: `git add
buschper/Resources/blv_foods.json && git commit -m "BLV-Daten" && git push`,
wenn du dich sicher fühlst.)

---

## 7c. Auf dem eigenen iPhone starten

1. iPhone per Kabel anschliessen, am iPhone **Vertrauen** bestätigen
2. In Xcode oben das iPhone als Ziel wählen
3. **⌘ + R**

Beim allerersten Mal: am iPhone **Einstellungen → Allgemein → VPN & Geräteverwaltung
→ Entwickler-App → deiner Apple-ID vertrauen**. Ausserdem verlangt iOS für
Entwickler-Apps den **Entwicklermodus**: **Einstellungen → Datenschutz & Sicherheit
→ Entwicklermodus** einschalten, iPhone startet neu.

Am iPhone muss unter **Einstellungen → [dein Name]** iCloud aktiv sein, sonst
gleicht nichts ab.

**Erst auf dem iPhone sinnvoll testbar:** Aktivkalorien und Schritte, Schlaf,
Gewicht von der Waage, Barcode mit der Kamera, QR-Code, Widget.

## 7d. TestFlight für dich und deine Partnerin

Alle Schritte stehen als Checkliste in [RELEASE.md](RELEASE.md) – vom App-Icon über
das Hochladen bis zur Einladung deiner Partnerin als interne Testerin. Interne
Tester brauchen keine Beta-Prüfung durch Apple; ein neuer Build ist nach dem
Hochladen in rund einer halben Stunde auf beiden iPhones.

Deine Partnerin hat danach ihre **eigene** buschper-Installation mit eigenem Profil
und eigenen Daten in ihrer iCloud. Mahlzeiten tauscht ihr über **Teile** (Datei
oder QR-Code) aus.

---

## 8. Wenn etwas schiefgeht

**Bei Build-Fehlern** zeigt der Issue Navigator in Xcode oft nur die halbe Meldung.
Vollständigen Text holen:

```bash
cd ~/Developer/buschper
xcodebuild -project buschper.xcodeproj -scheme buschper -sdk iphonesimulator build > /tmp/build.log 2>&1
grep -E "error:" /tmp/build.log
```

Schick mir die Ausgabe von `grep` – vollständig, als Text, nicht als Screenshot.

**Bei fehlschlagenden Tests:**

```bash
xcodebuild test -project buschper.xcodeproj -scheme buschper -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/test.log 2>&1
grep -E "(error|failed|Expectation)" /tmp/test.log
```

Falls es das Modell „iPhone 17 Pro“ bei dir nicht gibt, einen Namen aus
**Window → Devices and Simulators → Simulators** einsetzen.

**Wenn die App einfriert:** In Xcode den Pause-Knopf (⏸) drücken, dann
**Debug Navigator** (⌘ + 7) öffnen und den Stacktrace des Hauptthreads kopieren.

### Häufige Meldungen

| Meldung | Ursache und Lösung |
|---|---|
| `Signing requires a development team` | Schritt 2 fehlt, oder die Datei heisst noch `.example` |
| `Unable to open base configuration reference file` | `Config/Signing.xcconfig` fehlt – Projekt nochmals sauber holen |
| `An App ID with identifier ... is not available` | Bundle Identifier vergeben. In `project.pbxproj` `ch.hebera.buschper` auf etwas Eigenes ändern, ebenso iCloud-Container und App Group |
| `Provisioning profile ... doesn't include the com.apple.developer.healthkit entitlement` | HealthKit in Schritt 4 hinzufügen, dann einmal **Product → Clean Build Folder** (⇧⌘K) |
| `Unable to initialize without an iCloud account` | **Kein Fehler der App.** Der Simulator ist nicht bei iCloud angemeldet. Die App läuft lokal normal weiter |
| `The file "buschper.xcodeproj" couldn't be opened` | Xcode zu alt – es braucht Xcode 26 oder neuer |
| Im Simulator lässt sich nichts eintippen | **I/O → Keyboard → Toggle Software Keyboard** (⌘K) |
| `Multiple commands produce ... Info.plist` | Eine Info.plist ist in einen der Ordner `buschper/`, `buschperWidget/` oder `Shared/` gerutscht. Sie gehören nach `Config/` |
| Widget zeigt „buschper einisch öffne“ | Die App war seit der Installation noch nie offen, oder die App Group fehlt beim Widget-Target (Abschnitt 4) |
| `Embedded binary's bundle identifier is not prefixed with the parent app's` | Die Bundle ID des Widgets muss `ch.hebera.buschper.widget` sein |
| Barcode-Scan zeigt nur ein Eingabefeld | Im Simulator normal (keine Kamera). Auf dem iPhone: Kamera für buschper erlauben |
| Keine Schritte, kein Schlaf, keine Aktivkalorien | Health-Berechtigungen prüfen: Health-App → Profilbild → Apps → buschper → alles erlauben. Im Simulator gibt es keine solchen Daten |
| `Unable to find ... blv_foods.json` im Log | Kein Fehler: ohne BLV-Import nimmt buschper die Richtwert-Liste |

---

## 9. Git-Arbeitsweise

Du musst nichts committen – das mache ich. Dein einziger Befehl ist:

```bash
cd ~/Developer/buschper
git pull
```

Meldet `git pull`, lokale Änderungen würden überschrieben, betrifft das fast immer
`buschper.xcodeproj/project.pbxproj`, weil Xcode die Datei beim Öffnen neu
formatiert. Sichern und anschauen statt blind verwerfen:

```bash
git diff buschper.xcodeproj/project.pbxproj > ~/Desktop/buschper-local.diff
cat ~/Desktop/buschper-local.diff
```

Schick mir die Ausgabe. Ist es reine Umformatierung, kannst du sie verwerfen:

```bash
git checkout -- buschper.xcodeproj/project.pbxproj
git pull
```
