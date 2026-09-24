# buschper einrichten

Schritt für Schritt von „Projekt heruntergeladen“ bis „läuft auf dem iPhone“.
Jeder Schritt nennt den genauen Menüpfad. Wenn etwas nicht so aussieht wie
beschrieben, lieber nachfragen als raten.

**Voraussetzungen:** Mac mit Xcode 26 oder neuer, iPhone mit iOS 26 oder neuer,
Mitgliedschaft im Apple Developer Program (hast du).

> **Stand:** Schritt 1 von 10 ist umgesetzt: Projekt, Datenmodell und die
> Rechenlogik mit Tests. Die App startet mit leeren Platzhalter-Seiten. Diese
> Anleitung wächst mit jedem Schritt.

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

**Erwartung nach Schritt 1:** Die App startet dunkel mit vier Tabs. „Hüt“ zeigt
leere farbige Karten, „Erfasse“ öffnet ein Blatt mit vier runden Knöpfen,
„Schlaf“ und „Ig“ zeigen Platzhalter. Mehr kann sie noch nicht – es geht nur
darum, dass Projekt, Datenbank und Tests sauber bauen.

**Erwartungsmanagement:** Der Code wurde ohne Compiler geschrieben. Ein paar
Fehler beim ersten Bauen sind gut möglich. Schick mir den vollständigen
Fehlertext (Abschnitt 8).

---

## 7. CloudKit-Schema anlegen

*Kommt mit Schritt 2, sobald die Einstellungen einen Bereich „Entwicklung“ haben.*

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
