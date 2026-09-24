# buschper einrichten

**Entwurf.** Diese Anleitung wird mit dem Code vervollständigt. Sobald das
Xcode-Projekt steht, folgen hier die genauen Schritte für Signing, iCloud,
HealthKit, App Group, Widget und TestFlight, im gleichen Stil wie bei Frostify.

**Voraussetzungen:** Mac mit Xcode 26 oder neuer, iPhone mit iOS 26 oder neuer,
Mitgliedschaft im Apple Developer Program (hast du).

## 1. Projekt auf den Mac holen

Im **Terminal** (⌘ + Leertaste, „Terminal“ tippen, Enter):

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

Alternativ als ZIP: https://github.com/h18e/buschper → grüner Knopf **Code** →
**Download ZIP** → in `~/Developer/` entpacken.

> Den Projektordner **nicht** in iCloud Drive oder Dropbox legen, sondern in
> `~/Developer/`. Cloud-Platzhalterdateien bringen Git und Xcode unbemerkt
> durcheinander.

## 2. Was später dazukommt

- Team-ID in `Config/Signing.local.xcconfig` eintragen (wie bei Frostify)
- Capabilities prüfen: **iCloud (CloudKit)**, **HealthKit**, **App Groups**,
  **Push Notifications**
- Health-Berechtigungen beim ersten Start
- Testen auf dem iPhone (Health liefert im Simulator kaum Daten)
- TestFlight und deine Partnerin als interne Testerin (siehe RELEASE.md)
- Häufige Fehlermeldungen und ihre Lösung
