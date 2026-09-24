# buschper – Spezifikation (Version 1)

**Stand:** 2026-09-24 · **Status:** freigegeben, in Umsetzung · **Autor:** Claude Code für Raphi

Persönlicher Gesundheitstracker für iPhone. buschper erfasst Ernährung, Trinken,
Aktivität, Gewicht und Schlaf, zeigt alles auf einem frei gestaltbaren Dashboard
und sucht nach schlechten Nächten im Vortag nach Ursachen. Über die Zeit soll so
sichtbar werden, was *dir* den Schlaf verdirbt.

Diese Spezifikation fasst die Entscheide aus der Befragung vom 24.09.2026 zusammen
(Fragen Q1–Q39). Die Nummern stehen in Klammern, damit jeder Entscheid
nachvollziehbar bleibt.

---

## 1. Bestätigte Grundsätze

| Thema | Entscheid |
|---|---|
| Plattform | Native iOS-App, **SwiftUI**, Zielsystem **iOS 26+**, keine externen Pakete (Q1) |
| Repo | Eigenes Repo `h18e/buschper`, Arbeit direkt auf `main` (Q2, Q39) |
| Nutzer | **Eine Person pro Installation.** Deine Partnerin hat ihre eigene Installation mit eigenen Daten (Q3, Q38) |
| Daten | Core Data mit Abgleich über die **private** iCloud-Datenbank. Kein Server (Q3) |
| Verteilung | TestFlight für dich und deine Partnerin (interne Testerin). So gebaut, dass ein Release im App Store möglich bleibt (Q4, Q38) |
| Sprache | **Berndeutsch**, Du-Form, gleiche Schreibregeln wie Frostify (Q8) |
| Erscheinungsbild | **Nur dunkel**, eigenes Farbthema, jeder Bereich mit eigener Farbe (Q23, Q34) |
| Einheiten | kcal, g, ml / l, kg, cm (Q23) |
| Umfang | **Alles in Version 1**, keine Etappen (Q9) |
| Bundle ID | `ch.hebera.buschper` (analog Frostify) |

---

## 2. Aufbau der App (Q26)

Vier Tabs plus ein zentraler Erfassungsknopf:

| Tab | Inhalt |
|---|---|
| **Hüt** | Dashboard mit Karten, blätterbar nach Tagen (◀ ▶), darin die Tagesliste mit Mahlzeiten und Trainings |
| **＋** | Schnellerfassung als Auswahl: **Ässe · Trinke · Gwicht · Training** |
| **Schlaf** | Schlafscore-Graph, Liste der Nächte, Morgen-Einschätzung, Analyse und Muster |
| **Ig** | Profil, Ziele, Makros, eigene Produkte, Rezepte, Favoriten, Einstellungen, Export |

---

## 3. Farbthema (Q23, Q34)

Dunkler Grund, Karten leicht aufgehellt. Jeder Bereich hat eine feste Farbe, die
überall gleich bleibt: auf der Dashboard-Karte, im Graphen, im Erfassungsdialog.

| Bereich | Farbe |
|---|---|
| Ernährung / kcal / Makros | Grün |
| Flüssigkeit | Blau |
| Aktivität / Training | Rot |
| Gewicht | Gelb-Orange |
| Schlaf | Violett |

Farbe ist nie der einzige Träger einer Information: Zustände haben immer auch Text
oder Symbol (Barrierefreiheit). Die genauen Farbtöne lege ich bei der Umsetzung so
fest, dass sie auf dunklem Grund genug Kontrast haben. Du kannst sie danach
beliebig anpassen, sie stehen zentral in `Theme.swift`.

---

## 4. Profil und Ziele

### 4.1 Ersteinrichtung (Q35)

Beim ersten Start fragt buschper die Berechtigung für Apple Health an. Danach füllt
es aus Health vor, was dort hinterlegt ist: **Geburtsdatum, Geschlecht, Grösse,
aktuelles Gewicht**. Du bestätigst oder ergänzst:

- Ziel: **abnehmen / halten / zunehmen**
- Schlafziel (Vorgabe **8 h**)
- Schrittziel (Vorgabe **10'000**)
- Bewegungsprofil als Rückfallwert (siehe 4.3)

Fehlt etwas in Health, fragt buschper es direkt ab.

### 4.2 Kalorienbedarf: live (Q10, Q24)

```
Grundumsatz (Mifflin-St Jeor)
  Mann:  10 × kg + 6.25 × cm − 5 × Alter + 5
  Frau:  10 × kg + 6.25 × cm − 5 × Alter − 161

Tagesbudget = Grundumsatz + bisher verbrannte Aktivkalorien (Apple Health) + Ziel-Abschlag
```

- Das Budget **wächst über den Tag** mit den Aktivkalorien, so wie du es gewählt hast.
  Morgens ist es entsprechend knapper, abends grösser.
- Das Gewicht für die Formel ist der **Durchschnitt der letzten 7 Tage** (Q12).
  Ändert sich der berechnete Grundumsatz um mehr als 20 kcal, zeigt buschper
  einmalig einen Hinweis „Bedarf nöi berächnet“.
- Manuelle Trainings werden nach Health geschrieben (siehe 8) und kommen von dort
  als Aktivkalorien zurück. Sie werden nicht zusätzlich addiert, es gibt also keine
  Doppelzählung.

### 4.3 Rückfall ohne Aktivdaten (Q37)

Liefert Health **bis 12:00** keine Aktivkalorien für den Tag (Uhr nicht getragen,
Berechtigung verweigert), rechnet buschper mit dem Bewegungsprofil:

| Profil | Faktor |
|---|---|
| Sitzend | 1.2 |
| Leicht aktiv | 1.375 |
| Mässig aktiv | 1.55 |
| Sehr aktiv | 1.725 |
| Extrem aktiv | 1.9 |

`geschätzte Aktivkalorien = Grundumsatz × (Faktor − 1)`

Die Karte zeigt dann den Hinweis **„Schätzig“**. Treffen später echte Daten ein,
gelten wieder diese.

### 4.4 Ziel-Abschlag (Q11, Q25)

Ein fixer Wert in kcal pro Tag, frei änderbar. Vorgaben:

| Ziel | Abschlag |
|---|---|
| Abnehmen | −500 kcal |
| Halten | 0 kcal |
| Zunehmen | +300 kcal |

Untergrenze: Das Budget fällt nie unter **1'500 kcal (Mann) bzw. 1'200 kcal (Frau)**.
Greift diese Grenze, steht ein Hinweis dabei.

*Korrektur beim Umsetzen:* Ursprünglich stand hier „nie unter den Grundumsatz“.
Mit dem Live-Budget hätte das beim Abnehmen jeden Morgen den Abschlag aufgehoben,
weil vor dem ersten Schritt noch keine Aktivkalorien da sind: Grundumsatz − 500
wäre immer unter dem Grundumsatz. Die festen Mindestwerte sind die übliche
Untergrenze für eine Reduktionskost.

### 4.5 Makroziele (Q11, Q25)

- Verteilung in **Prozent der kcal**, anpassbar. Vorgabe **KH 45 % · Eiweiss 25 % · Fett 30 %**.
- Die Summe muss 100 % ergeben. Die Einstellung lässt sich erst sichern, wenn das stimmt.
- Umrechnung in Gramm: KH und Eiweiss 4 kcal/g, Fett 9 kcal/g. Weil das Budget
  live wächst, wachsen die Gramm-Ziele im gleichen Verhältnis mit.
- **Ballaststoffe:** eigenes Mindestziel, Vorgabe **30 g**.

### 4.6 Flüssigkeitsziel (Q14)

```
Ziel = 35 ml × kg (7-Tage-Schnitt) + 500 ml pro Stunde Training
```

Trainingszeit aus Health und aus manuellen Trainings. Das Ziel lässt sich von Hand
übersteuern (fester Wert in ml).

---

## 5. Ernährung

### 5.1 Nährwerte (Q28)

Geführt werden **pro 100 g bzw. 100 ml** eines Produkts und als fertige Summe pro
Eintrag:

| Wert | Einheit | Pflicht |
|---|---|---|
| Energie | kcal | **ja** |
| Kohlenhydrate | g | |
| davon Zucker | g | |
| Fett | g | |
| davon gesättigte Fettsäuren | g | |
| Eiweiss | g | |
| Ballaststoffe | g | |
| Salz | g | |
| Alkohol | g | |
| Koffein | mg | |

Nicht erfasste Werte bleiben **leer**, nicht 0. So unterscheidet die App zwischen
„nicht bekannt“ und „enthält nichts“. Summen zeigen einen Hinweis, wenn Werte fehlen.

### 5.2 Mahlzeit-Kategorien (Q15)

**Zmorge · Znüni · Zmittag · Zvieri · Znacht · Snack**

Jeder Eintrag hat **Datum und Uhrzeit**. Die Kategorie wird aus der Uhrzeit
vorgeschlagen und lässt sich ändern:

| Uhrzeit | Vorschlag |
|---|---|
| 05:00–09:29 | Zmorge |
| 09:30–10:59 | Znüni |
| 11:00–13:59 | Zmittag |
| 14:00–17:29 | Zvieri |
| 17:30–21:59 | Znacht |
| sonst | Snack |

### 5.3 Erfassen: der Weg „Ässe“ (Q27)

1. Zeitpunkt (Vorgabe: jetzt) und Kategorie (Vorschlag)
2. Oben: **Suchfeld** und **Barcode-Knopf**
3. Darunter, ohne Suche: **Favoriten**, **Zletscht bruucht** (automatisch),
   **Eigeni Produkt**, **Rezept**
4. Knöpfe **„Schnäll-Iitrag“** (Kantine, siehe 5.6) und **„Nöis Produkt“**
5. Ein Produkt antippen → Menge wählen → es landet im **Chörbli** der Mahlzeit.
   Mehrere Produkte nacheinander, am Schluss einmal sichern.

**Menge:** in g bzw. ml, oder in einer eigenen **Portionsgrösse** des Produkts
(z. B. „1 Schiibe = 30 g“, „1 Stück = 120 g“). Portionsgrössen definierst du pro
Produkt beliebig.

### 5.4 Quellen und Suchreihenfolge (Q6)

| Rang | Quelle | Netz nötig |
|---|---|---|
| 1 | Eigene Produkte (inkl. korrigierte Kopien) | nein |
| 2 | Favoriten und Zuletzt verwendet | nein |
| 3 | Rezepte | nein |
| 4 | **Schweizer Nährwertdatenbank (BLV)**, in die App eingebaut | nein |
| 5 | **Open Food Facts** (Textsuche und Barcode) | ja |

**Barcode:** VisionKit wie in Frostify. Zuerst eigene Produkte, dann Open Food
Facts, sonst ein leeres Formular „Nöis Produkt“ mit dem Barcode vorausgefüllt.

**BLV-Daten:** Die Tabelle wird einmal mit einem Skript (`tools/`) in eine
kompakte JSON-Datei umgewandelt und mit der App ausgeliefert. Die Nutzungsbedingungen
(Quellenangabe) prüfe ich vor dem Einbau. Falls sie eine Auslieferung in der App
nicht erlauben, melde ich mich, bevor ich etwas anderes mache.

**Open Food Facts:** Übertragen wird nur der Barcode bzw. der Suchbegriff. Die
Abfrage ist in den Einstellungen abschaltbar, wie bei Frostify.

### 5.5 Eigene Produkte, Favoriten, Korrekturen (Q29)

- Eigene Produkte: Name, Marke (optional), Barcode (optional), fest oder flüssig,
  Nährwerte pro 100 g/ml, Portionsgrössen.
- Jedes Produkt, auch aus BLV und Open Food Facts, lässt sich mit ☆ zum
  **Favoriten** machen.
- **Korrektur an einem Open-Food-Facts- oder BLV-Produkt** erzeugt automatisch
  eine eigene Kopie. Beim nächsten Scan desselben Barcodes gewinnt deine Version.
- Wird ein fremdes Produkt geloggt, merkt sich buschper es lokal
  (für „Zletscht bruucht“), ohne es zu einem eigenen Produkt zu machen.

### 5.6 Schnell-Iitrag (Kantine) (Q16)

Für ein ganzes Gericht, dessen Zutaten du nicht kennst:

- Name (z. B. „Pasta Kantine“)
- **Variante Makros:** KH, Eiweiss, Fett in g, optional Ballaststoffe und Alkohol.
  Die kcal rechnet die App: `KH × 4 + Eiweiss × 4 + Fett × 9 + Alkohol × 7`
- **Variante nur kcal:** Makros bleiben leer

Wird **nicht** als eigenes Produkt oder Rezept gespeichert, sondern lebt nur als
Eintrag in der Mahlzeit. Beim Kopieren einer Mahlzeit kommt er mit.

### 5.7 Rezepte (Q17)

- Name, **Anzahl Portionen**, Zutaten mit Menge. Zutaten kommen aus allen Quellen
  von 5.4, ausser anderen Rezepten (**nicht verschachtelt**).
- Nährwerte pro Portion werden aus den Zutaten berechnet.
- Geloggt wird in **Portionen** (Schritte zu 0.25, z. B. 1.5 Portionen).
- Rezepte lassen sich bearbeiten, duplizieren und zum Favoriten machen.

### 5.8 Kopieren (Q15)

- Eine ganze **Mahlzeit** (Kategorie eines Tages) oder **einzelne Einträge**
  markieren → **„Kopiere“** → Zieltag, Zeit und Kategorie wählen → einfügen.
- Kurzweg: „Wie geschter“ bei einer leeren Kategorie übernimmt dieselbe
  Kategorie vom Vortag.

### 5.9 Bearbeiten

Alles, was du in buschper erfasst hast, ist bearbeitbar und löschbar: Einträge,
Mengen, Zeitpunkt, Kategorie, Produkte, Rezepte, Getränke, Trainings, manuelle
Gewichte. Bei Änderungen passt buschper auch den zugehörigen Wert in Apple Health an.
Technisch heisst das: den alten Wert löschen und einen neuen schreiben, weil Health
keine Änderungen zulässt.

**Snapshot-Prinzip:** Ein geloggter Eintrag speichert seine Nährwerte als feste
Kopie. Änderst du später ein Produkt oder Rezept, bleibt die Vergangenheit, wie sie
war. Beim Bearbeiten eines Eintrags kannst du ihn mit „Wärt nöi lade“ auf den
aktuellen Stand des Produkts bringen.

---

## 6. Teilen von Mahlzeiten (Q18, Q31)

Nur zwischen buschper-Installationen, ohne Server:

| Weg | Wie |
|---|---|
| **WhatsApp, iMessage und Co.** | „Teile“ öffnet das iOS-Teilen-Blatt mit einer Datei **`<Name>.buschper`**. Tippt die Empfängerin sie an, öffnet sich buschper. |
| **QR-Code** | buschper zeigt einen QR-Code an. Sie scannt ihn mit der normalen Kamera oder im Scanner von buschper. |

**Inhalt:** Name der Mahlzeit, Kategorie, alle Einträge mit Menge und Nährwert-Snapshot.
Keine Personendaten, kein Datum.

**Beim Import** wählt die Empfängerin (Q31 c):
- **„I mym Tag iifüege“**: Tag, Uhrzeit und Kategorie wählen
- **„Als Vorlag spychere“**: wird zu einem Rezept mit 1 Portion

**Grenze QR-Code:** Ein QR-Code fasst knapp 3 KB. Die Daten werden komprimiert.
Bei sehr grossen Mahlzeiten (grob ab 25 Einträgen) bietet buschper nur noch die
Datei an und sagt, warum.

---

## 7. Trinken (Q13, Q14)

### 7.1 Erfassen

- **Schnelltasten:** 250 ml, 500 ml, dazu eigene Grössen
- **Getränketyp:** Wasser, Mineral, Tee, Kaffee, Milch, Saft, Süssgetränk, Bier,
  Wein, Spirituose, Eigenes. Eigene Getränke lassen sich als Vorlage speichern
  (z. B. „Cappuccino 2 dl“).
- Jedes Getränk hat Menge, Zeitpunkt und optional Nährwerte.

### 7.2 Was wohin zählt

| Getränk | Flüssigkeit | kcal / Makros | Alkohol | Koffein |
|---|---|---|---|---|
| Wasser, Mineral | ✔ | – | – | – |
| Tee, Kaffee | ✔ | wenn Nährwerte | – | ✔ (Vorgabe pro Typ) |
| Milch, Saft, Süssgetränk | ✔ | ✔ | – | bei Cola / Energy |
| Bier, Wein, Spirituose | **✘** | ✔ | ✔ aus Vol-% | – |

Alkohol in g = `ml × Vol-% / 100 × 0.789`.

Kalorienhaltige Getränke erscheinen **in der Tagesliste** und in den kcal, aber
auch in der Flüssigkeitskarte, damit nichts doppelt erfasst werden muss.

---

## 8. Apple Health (Q7, Q30)

### 8.1 Lesen

| Daten | Verwendung |
|---|---|
| Aktivkalorien | Tagesbudget (4.2) |
| Schritte, Trainingsminuten, Trainings | Aktivität (10) |
| Gewicht | Gewichtsverlauf, Bedarf |
| Schlaf (Phasen Kern/Tief/REM/Wach) | Schlafscore (11) |
| Geburtsdatum, Geschlecht, Grösse | Profil |

### 8.2 Schreiben

| Daten | Health-Typ |
|---|---|
| Mahlzeiten | Nahrungs-Korrelation mit kcal, KH, Zucker, Fett, gesättigten Fettsäuren, Eiweiss, Ballaststoffen, Natrium (aus Salz), Koffein |
| Wasser | Wasser (nur Getränke, die als Flüssigkeit zählen) |
| Manuelles Gewicht | Körpergewicht |
| Manuelle Trainings | Training mit Energie |

### 8.3 Regeln

- **Keine Doppelzählung:** Beim Lesen erkennt buschper seine eigenen Einträge an
  der Quelle und zählt sie nicht ein zweites Mal.
- **Ernährungs- und Wasserdaten anderer Apps werden nicht gelesen.** Sie kommen
  nur aus buschper.
- **Fremde Werte** (Waage, Apple Watch) sind nur lesbar. Einzelne Werte lassen sich
  **ignorieren**, z. B. eine falsche Waagen-Messung. Sie fliessen dann nicht mehr in
  Graphen und Berechnungen ein. Rückgängig machen geht jederzeit.
- **Geschrieben wird nur auf dem Gerät, auf dem ein Eintrag erfasst wurde.** Health
  gleicht selbst zwischen deinen Geräten ab. Würde jedes Gerät schreiben, stünde
  alles doppelt drin.
- Verweigerst du eine Berechtigung, läuft der betroffene Teil ohne Health weiter
  (z. B. Gewicht nur manuell), mit einem Hinweis, wo man es einschaltet.

### 8.4 Apples eigener Schlafscore (Q5)

Stand heute gibt Apple seinen Schlafscore nicht an andere Apps weiter. buschper
berechnet deshalb einen eigenen (11). Beim Umsetzen prüfe ich, ob sich das mit
iOS 26 geändert hat. Falls ja, melde ich mich mit einem Vorschlag.

---

## 9. Gewicht (Q12, Q30)

- Quelle: Apple Health (z. B. Waage), dazu **manuelle Einträge** über ＋ → Gwicht,
  die nach Health geschrieben werden.
- Graph mit Tageswerten (bei mehreren Messungen der tiefste Wert des Tages, weil
  das meist die Morgen-Messung ist) und einer Linie für den 7-Tage-Schnitt.
- Karte: aktuelles Gewicht, Veränderung über den gewählten Zeitraum, Zielgewicht
  (optional).

---

## 10. Aktivität (Q21, Q33)

### 10.1 Aktivitätsgrad

Die Karte ist im Stil deines Screenshots aufgebaut: grosse Schrittzahl, dein
30-Tage-Schnitt und eine Stufe.

| Schritte heute | Stufe |
|---|---|
| < 5'000 | Tief |
| 5'000–7'499 | Liecht |
| 7'500–9'999 | Moderat |
| ≥ 10'000 | Aktiv |

Die Schwellen richten sich nicht nach dem Schrittziel, das Ziel ist ein eigener
Balken. Dazu kommen Aktivkalorien und Trainingsminuten als kleine Zusatzzahlen.

### 10.2 Manuelle Trainings

- Sportart (Liste mit Symbolen: Laufen, Velo, Wandern, Schwimmen, Kraft, Yoga,
  Ski, Tanzen, Eigenes …), Start, Dauer, Intensität (liecht / mittu / hert)
- kcal-Schätzung: `MET × kg × Stunden`, der MET-Wert kommt aus Sportart und
  Intensität. Die kcal lassen sich von Hand überschreiben.
- Wird nach Health geschrieben.

### 10.3 Tagesliste

Trainings erscheinen **chronologisch zwischen den Mahlzeiten**
(„Laufe · 430 kcal · 45 min“), aus Health und manuell.

---

## 11. Schlaf

### 11.1 Welche Nacht gehört zu welchem Tag

Die Nacht, die am Morgen von Tag *D* endet, gehört zu *D*. Ihr **Vortag** ist
*D − 1* von 00:00 bis zum Einschlafen.

### 11.2 Schlafscore 0–100 (Q19)

| Komponente | Gewicht | Volle Punkte | 0 Punkte |
|---|---|---|---|
| Dauer (Schlafzeit im Vergleich zum Ziel) | 40 | ≥ Ziel | ≤ 50 % des Ziels |
| Tiefschlaf-Anteil | 20 | 13–23 % | ≤ 5 % |
| REM-Anteil | 15 | 20–25 % | ≤ 8 % |
| Wachphasen nach dem Einschlafen | 15 | ≤ 10 min | ≥ 60 min |
| Regelmässigkeit (Einschlafzeit im Vergleich zum 14-Tage-Median) | 10 | ≤ 15 min | ≥ 90 min |

Dazwischen linear. **Ohne Schlafphasen** (nur iPhone, keine Uhr) werden Tief und
REM weggelassen und die übrigen Gewichte hochgerechnet. Die Nacht bekommt den
Hinweis „ohni Phase“.

Die Gewichte und Schwellen stehen an einer Stelle im Code (`SleepScore.swift`)
und sind getestet.

### 11.3 Morgen-Einschätzung (Q19)

Optional **1–5 Sterne**: „Wie guet hesch gschlafe?“. Wird zur Nacht gespeichert.
Eine Erinnerung dafür lässt sich einschalten (15).

### 11.4 Wann ist eine Nacht schlecht? (Q19)

Eine Nacht gilt als **schlecht**, wenn mindestens eines zutrifft:

- Score **< 60**
- Score **mindestens 10 Punkte unter** deinem 30-Tage-Schnitt
- Morgen-Einschätzung **1 oder 2 Sterne**

Alle drei Schwellen sind einstellbar.

### 11.5 Schlaf-Tab

- Graph Schlafscore mit Umschalter **Wuche / Monet / 3 Mönet** (Vorgabe Monet)
- Liste der Nächte: Score, Dauer, Phasenbalken, Sterne, schlechte Nächte markiert
- Detail einer Nacht: Komponenten des Scores, Vortagsanalyse (12), Notiz

---

## 12. Schlafanalyse (Q20, Q32)

### 12.1 Grundsatz

**Regelbasiert und nachvollziehbar.** Keine KI, nichts Erfundenes. Jede Aussage
lässt sich auf Zahlen zurückführen. Überall steht der Hinweis:
*„Kei medizinischi Beratig.“*

### 12.2 Pro Nacht gespeichert

Für **jede** Nacht, nicht nur die schlechten, damit verglichen werden kann:

- Score, Komponenten, Morgen-Einschätzung, schlecht ja/nein
- Kennzahlen des Vortags: kcal und Bilanz, Makros, Fettanteil Znacht,
  Zeitpunkt der letzten Mahlzeit, Alkohol, Koffein und Zeitpunkt des letzten
  Koffeins, Flüssigkeit in % vom Ziel, Schritte, Trainings
- **Ausgelöste Faktoren** (12.3)
- **Eigene Notiz** (frei und mit Schnellmarken: Stress, Chrank, Reise,
  Lärm, Chind wach) und der Schalter **„Us Uswärtig usschliesse“**

Die Analyse einer Nacht wird neu berechnet, wenn du Daten des Vortags nachträglich
änderst.

### 12.3 Faktoren (alle Schwellen einstellbar)

| Faktor | Auffällig wenn |
|---|---|
| Alkohol | > 0 g (Menge wird gespeichert) |
| Koffein spät | Koffein nach 14:00 |
| Spät gässe | letzte Mahlzeit nach 20:00 |
| Schwärs Znacht | Znacht > 35 % der Tages-kcal **oder** Fettanteil Znacht > 40 % |
| Kalorie-Bilanz | > 20 % über oder unter dem Budget |
| Z’weni trunke | < 70 % des Flüssigkeitsziels |
| Z’weni Bewegig | Schritte < 50 % deines 30-Tage-Schnitts |
| Spats Training | Training mit Intensität hert oder ≥ 70 % max. Puls endet < 2 h vor dem Einschlafen |

### 12.4 Muster (die eigentliche Erkenntnis)

Für jeden Faktor vergleicht buschper die Nächte **mit** diesem Faktor am Vortag
mit den Nächten **ohne**:

- Durchschnittlicher Score mit und ohne Faktor
- Anteil schlechter Nächte mit und ohne Faktor
- Anzahl Nächte in beiden Gruppen

Angezeigt wird ein Muster erst, wenn **beide Gruppen mindestens 5 Nächte** haben.
Vorher steht dort „No z’weni Date (3 vo 5)“. Beispiel:

> **Alkohol**: I Nächt nach Alkohol isch dy Score im Schnitt **14 Pünkt tiefer**
> (62 statt 76, 11 vs. 38 Nächt). 9 vo 11 Nächt ware schlächt.

Muster werden nach Stärke sortiert. Ausgeschlossene Nächte zählen nicht mit.

---

## 13. Dashboard „Hüt“ (Q22, Q34)

### 13.1 Karten

| Karte | Inhalt | Farbe |
|---|---|---|
| **Kalorie & Makros** | kcal gegessen / Budget, KH, Eiweiss, Fett, Ballaststoffe als Ist/Ziel | Grün |
| **Tagesliste** | Mahlzeiten mit Nährwerten und Trainings chronologisch, **eigener scrollbarer Bereich** | Grün / Rot |
| **Flüssigkeit** | ml / Ziel, Flaschen-Darstellung wie im Screenshot, Schnelltaste +250 ml | Blau |
| **Aktivität** | Schritte, Schnitt, Stufe, Aktivkalorien, Trainingsminuten | Rot |
| **Gewicht** | Graph, aktueller Wert, Veränderung | Gelb-Orange |
| **Schlaf** | Score der letzten Nacht, Graph | Violett |
| **Wuchenschnitt** | Schnitt kcal und Makros der letzten 7 Tage im Vergleich zum Ziel | Grün |

### 13.2 Verhalten

- **Bearbeiten-Modus:** Karten **ein-/ausschalten** und per Drag & Drop
  **umsortieren**. Die Einstellung wird gespeichert.
- **Tage blättern** mit ◀ ▶ bzw. Wischen über den Datumskopf. Ein Tipp auf das
  Datum springt zu „Hüt“.
- **Graphen** (Gewicht, Schlaf, Flüssigkeit): Umschalter **Wuche / Monet / 3 Mönet**,
  Vorgabe Monet (30 Tage).
- Eine Karte antippen öffnet die Detailansicht des Bereichs.

---

## 14. Widget (Q36)

| Grösse | Inhalt |
|---|---|
| Klein | kcal übrig, Flüssigkeit in % |
| Mittel | kcal übrig mit Makros, Flüssigkeit, Knopf **„+250 ml“** |

Der Knopf erfasst Wasser direkt, ohne die App zu öffnen. Der Health-Eintrag dazu
wird beim nächsten Öffnen der App nachgeschrieben, weil das Widget selbst nicht
nach Health schreiben darf. Das Widget braucht dafür eine gemeinsame
Datenablage mit der App (App Group).

---

## 15. Erinnerungen (Q23)

Beide **standardmässig aus**, lokal geplant, kein Server:

- **Trinke:** z. B. alle 2 h zwischen 09:00 und 19:00, nur wenn du hinter dem
  Tagesziel liegst (wird bei jedem App-Start neu geplant)
- **Morge-Iischätzig:** zu einer festen Zeit, z. B. 07:30

---

## 16. Export (Q23)

**Ig → Date exportiere** erzeugt CSV-Dateien (Excel-tauglich, Semikolon, UTF-8)
und öffnet das Teilen-Blatt:

- `mahlzeiten.csv`: ein Eintrag pro Zeile mit allen Nährwerten
- `getraenke.csv`, `trainings.csv`, `gewicht.csv`
- `schlaf.csv`: Nächte mit Score, Komponenten, Faktoren, Notiz

Zeitraum wählbar (alles / letzte 30 / 90 Tage).

---

## 17. Datenmodell (Core Data)

Regeln wegen des iCloud-Abgleichs: keine Eindeutigkeitsregeln, alle Beziehungen
optional mit Gegenbeziehung, jedes Feld optional oder mit Vorgabewert. Die
Nährwerte stehen überall als dieselben zehn Felder (5.1), unten als **[N]**
abgekürzt.

| Entität | Wichtige Felder |
|---|---|
| **Profile** (genau eine) | sex, birthDate, heightCm, goal, goalOffsets (3), macroPctCarbs/Protein/Fat, fiberMinG, activityProfile, sleepGoalMin, stepGoal, waterGoalOverrideMl?, targetWeightKg?, dashboardLayout (JSON), factorThresholds (JSON), badNightRules (JSON) |
| **FoodProduct** | id, name, brand?, barcode?, isLiquid, origin (own / offCopy / blvCopy), **[N] pro 100**, isFavorite, useCount, lastUsedAt → portions |
| **PortionSize** | id, name, grams → product |
| **ExternalFoodRef** | id, source (off / blv), externalId, name, **[N] pro 100**, isFavorite, lastUsedAt. Merkt sich fremde Produkte für Favoriten und „Zletscht bruucht“ |
| **Recipe** | id, name, servings, isFavorite, lastUsedAt → ingredients |
| **RecipeIngredient** | id, name, amountG, **[N] pro 100** (Snapshot), sourceKind, sourceId → recipe |
| **Meal** | id, timestamp, category, title? → entries |
| **FoodEntry** | id, name, amount, unitLabel, **[N] Summe** (Snapshot), kind (product / external / recipe / quick), sourceId?, servings? → meal |
| **DrinkEntry** | id, timestamp, drinkType, volumeMl, countsAsFluid, abvPercent?, **[N] Summe**, presetId? |
| **DrinkPreset** | id, name, drinkType, volumeMl, abvPercent?, **[N] pro 100** |
| **WorkoutEntry** | id, start, durationMin, sportType, intensity, kcal, kcalIsManual |
| **WeightEntry** | id, timestamp, kg (nur manuelle) |
| **NightRecord** | id, nightDate, score, components (JSON), asleepMin, deepMin, remMin, awakeMin, bedtime, wakeTime, hasStages, rating?, isBad, factors (JSON), dayMetrics (JSON), note?, tags, excluded, computedAt |
| **IgnoredHealthSample** | uuid, kind, ignoredAt |
| **HealthLink** | localId, sampleUUID, deviceId, pendingWrite. Verbindet eigene Einträge mit ihren Health-Werten, damit Ändern und Löschen dort nachgezogen wird |

Erinnerungen und der Schalter für Open Food Facts liegen **pro Gerät** (nicht im
Profil), weil jedes Gerät seine Mitteilungen selbst plant.

Das Modell wird mit `tools/generate_model.py` aus einer einzigen Definition
erzeugt (Modell-XML und Entitätsklassen), damit beide nie auseinanderlaufen.

Gesundheitsdaten aus Health (Schritte, Aktivkalorien, fremde Gewichte, Schlafphasen)
werden **nicht** in Core Data kopiert, sondern bei Bedarf gelesen. Ausnahme ist
`NightRecord`, das die berechnete Auswertung festhält.

---

## 18. Tech-Stack und Architektur

| Baustein | Wahl |
|---|---|
| UI | SwiftUI, iOS 26+, `@Observable` |
| Graphen | Swift Charts (Apple, kein Fremdpaket) |
| Daten | Core Data + `NSPersistentCloudKitContainer` (nur private Datenbank), Speicher in der App Group, damit das Widget mitlesen kann |
| Health | HealthKit |
| Barcode | VisionKit `DataScannerViewController` (aus Frostify übernommen) |
| QR erzeugen / lesen | Core Image / VisionKit |
| Teilen | Eigener Dateityp `ch.hebera.buschper.meal` (`.buschper`), `ShareLink` |
| Widget | WidgetKit + App Intents (interaktiver Knopf) |
| Erinnerungen | `UNUserNotificationCenter`, lokal |
| Tests | Swift Testing für die gesamte Rechenlogik |
| Abhängigkeiten | keine externen Pakete |

**Warum Core Data und nicht SwiftData?** In Frostify war das Teilen der Grund. In
buschper gibt es kein CloudKit-Sharing, SwiftData wäre also möglich. Ich bleibe
trotzdem bei Core Data: Die Persistenz, der Abgleich und die Prüfwerkzeuge aus
Frostify (`tools/verify_structure.py`) sind erprobt und lassen sich übernehmen.
Zudem sind für SwiftData mit CloudKit unter iOS 26 Probleme beim Abgleich gemeldet.

### 18.1 Ordnerstruktur

```
buschper/
├── App/            Einstieg, Tabs, Import von .buschper-Dateien und QR-Links
├── Model/          Core-Data-Modell, Entitäten, Enums (Kategorien, Getränke, Sportarten)
├── Domain/         Reine Rechenlogik ohne Core Data und HealthKit, voll getestet:
│                   Bedarf, Makros, Flüssigkeit, Schlafscore, Faktoren, Muster,
│                   MET, Alkohol, Portionen, Teilen-Format, CSV
├── Persistence/    Container, Repositories
├── Health/         HealthKit lesen/schreiben, Abgleich, Doppelzählungs-Filter
├── Food/           BLV-Katalog, Open-Food-Facts-Client, Suche über alle Quellen
├── Features/       Dashboard, Erfassen (Ässe, Trinke, Gwicht, Training), Produkte,
│                   Rezepte, Schlaf, Analyse, Profil, Einstellungen, Teilen, Export
├── Services/       Erinnerungen, Einstellungen
├── Theme/          Farben, Karten, Bausteine
└── Resources/      Assets, BLV-Daten
buschperWidget/     Widget-Erweiterung
buschperTests/      Tests
tools/              BLV-Umwandlung, Strukturprüfung, Textliste
```

### 18.2 Schichtenregel

- **Domain** kennt weder Core Data noch HealthKit noch SwiftUI. Alles, was
  gerechnet wird, liegt hier und bekommt Tests.
- **Health** und **Persistence** liegen hinter Protokollen. Die Views sehen nur
  ViewModels. So läuft die App auch im Simulator mit Beispieldaten, wo Health
  nur eingeschränkt verfügbar ist.

---

## 19. Getroffene Entscheidungen im Überblick

| # | Punkt | Entscheid |
|---|---|---|
| Q1 | Plattform | Native SwiftUI, iOS 26+, keine Pakete |
| Q2 | Repo | Eigenes Repo `h18e/buschper` |
| Q3 | Nutzer / Daten | Eine Person, privater iCloud-Abgleich, kein Server |
| Q4 | Verteilung | TestFlight, release-fähig gebaut |
| Q5 | Schlafscore | Eigener Score |
| Q6 | Datenbanken | Eigene → BLV (offline) → Open Food Facts |
| Q7 | Health schreiben | Ernährung, Wasser, Gewicht, Trainings |
| Q8 | Sprache | Berndeutsch |
| Q9 | Umfang | Alles in Version 1 |
| Q10 / Q24 | Bedarf | Grundumsatz + **live** Aktivkalorien |
| Q11 / Q25 | Ziel / Makros | Fixer Abschlag, %-Verteilung 45/25/30 anpassbar |
| Q12 | Gewicht → Bedarf | Automatisch über 7-Tage-Schnitt |
| Q13 | Getränke | Typ + Menge + Nährwerte, Alkohol in g, Koffein |
| Q14 | Flüssigkeitsziel | 35 ml/kg + 500 ml pro Trainingsstunde |
| Q15 | Kategorien | Zmorge … Snack, aus Uhrzeit vorgeschlagen |
| Q16 | Schnell-Iitrag | Makros oder nur kcal, **nicht** als Produkt gespeichert |
| Q17 | Rezepte | In Portionen, nicht verschachtelt |
| Q18 / Q31 | Teilen | Nur buschper ↔ buschper, Datei + QR, Import wählbar |
| Q19 | Score / schlechte Nacht | Formel 11.2, Schwellen 11.4, Sterne |
| Q20 / Q32 | Analyse | Regelbasiert, alle Nächte, Muster ab 5 Nächten |
| Q21 / Q33 | Aktivität | Schritt-Stufen, Zusatzzahlen, Trainings in der Tagesliste |
| Q22 | Dashboard | Ein-/ausblenden, umsortieren, blättern, Mahlzeiten scrollbar |
| Q23 / Q34 | Design | Nur dunkel, Bereichsfarben, Graph-Umschalter |
| Q26 | Tabs | Hüt · ＋ · Schlaf · Ig |
| Q27 | Erfassen | Chörbli, Portionsgrössen, Zletscht bruucht |
| Q28 | Nährwerte | 10 Werte, nur kcal Pflicht |
| Q29 | Korrekturen | Eigene Kopie gewinnt |
| Q30 | Fremde Health-Werte | Nur lesbar, ignorierbar, keine fremde Ernährung |
| Q35 | Ersteinrichtung | Aus Health vorausfüllen |
| Q36 | Widget | Klein + mittel mit „+250 ml“ |
| Q37 | Rückfall | Bewegungsprofil ab 12:00, Hinweis „Schätzig“ |
| Q38 | Partnerin | Eigene Installation, interne TestFlight-Testerin |
| Q39 | Branch | `main` |

**Bewusst nicht in Version 1:** Apple Watch, KI-Auswertung, Teilen mit Menschen
ohne buschper, verschachtelte Rezepte, Import von Ernährungsdaten anderer Apps,
Hell-Modus.

---

## 20. Ehrliche Einschränkungen

- Diese Umgebung ist Linux. Ich kann **nicht kompilieren** und die App nicht
  starten. Ich prüfe den Code strukturell (Klammern, Projektdatei, Datenmodell,
  Texte). Den Build-Nachweis erbringst du in Xcode.
- Der Umfang liegt grob bei 10'000–15'000 Zeilen. Beim ersten Öffnen sind
  Compile-Fehler wahrscheinlich. Die arbeiten wir anhand der exakten Fehlertexte ab.
- HealthKit liefert im Simulator nur, was man von Hand einträgt. Aktivität und Schlaf
  lassen sich realistisch nur auf deinem iPhone testen.
- Die Schlafanalyse wird erst nach einigen Wochen aussagekräftig. Das liegt in der
  Natur der Sache.

---

## 21. Umsetzungsreihenfolge nach der Freigabe

Alles kommt in Version 1. Gebaut wird trotzdem in dieser Reihenfolge, damit du
möglichst früh etwas Lauffähiges testen kannst:

1. Xcode-Projekt, Theme, Datenmodell, Persistenz, Domain-Logik mit Tests
2. Profil, Ersteinrichtung, HealthKit-Anbindung, Bedarfsberechnung
3. Ernährung: Suche, eigene Produkte, Barcode, BLV, Open Food Facts, Chörbli,
   Schnell-Iitrag, Favoriten
4. Trinken, Gewicht, Training
5. Dashboard mit allen Karten und Bearbeiten-Modus
6. Rezepte, Kopieren, Teilen (Datei + QR)
7. Schlaf: Score, Tab, Morgen-Einschätzung
8. Schlafanalyse und Muster
9. Widget, Erinnerungen, Export
10. SETUP.md und RELEASE.md vervollständigen

Nach jedem Schritt committe und pushe ich und sage dir, was du testen kannst.

---

## 22. Freigabe

Bitte lies diese Spezifikation durch. Korrekturen einfach als nummerierte Liste
schicken. Mit **„Freigabe“** oder **„Los“** beginne ich mit Schritt 1.
