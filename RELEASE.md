# buschper – Checkliste vor einer Verteilung

Alles hier kann nur ein Mensch erledigen: Es braucht Zugang zu App Store Connect,
zum Apple-Entwicklerportal oder eine gestalterische Entscheidung. Den Status bitte
laufend nachführen.

## TestFlight (für dich und deine Partnerin)

| Status | Punkt | Was genau |
|---|---|---|
| ☐ | **App in App Store Connect anlegen** | https://appstoreconnect.apple.com → **Apps** → **+** → **Neue App**, Bundle ID `ch.hebera.buschper` |
| ☐ | **Partnerin als interne Testerin** | App Store Connect → **Benutzer und Zugriff** → **+** → ihre Apple-ID einladen, Rolle z. B. **Marketing** oder **Kundensupport**. Danach in der App unter **TestFlight → Interne Tests** hinzufügen. Interne Tester brauchen **keine** Beta-Prüfung durch Apple. |
| ☐ | **CloudKit-Schema nach Production** | https://icloud.developer.apple.com/dashboard → Container `iCloud.ch.hebera.buschper` → **Deploy Schema to Production**. Ohne diesen Schritt gleicht die TestFlight-Version nichts ab. |
| ☐ | **aps-environment auf production** | In der Entitlements-Datei muss für TestFlight `production` stehen. |
| ☐ | **Versionsnummer** | Jede hochgeladene Version braucht eine neue Build-Nummer. |
| ☐ | **Export-Compliance** | buschper nutzt nur die Standardverschlüsselung von iOS. In der Regel: „Verwendet keine nicht-exemptierte Verschlüsselung“. |
| ☐ | **App-Icon** | 1024 × 1024 px PNG, **kein Alphakanal**, randlos, sRGB. In Xcode: `buschper/Resources/Assets.xcassets` → `AppIcon` → Bild hineinziehen. Bis dahin hat die App kein Icon – für TestFlight ist eines Pflicht. |
| ☐ | **Hochladen** | In Xcode oben als Ziel **Any iOS Device (arm64)** wählen → **Product → Archive** → im Organizer **Distribute App** → **TestFlight & App Store** → durchklicken. Das Widget wird automatisch mitgenommen. |
| ☐ | **Build freigeben** | App Store Connect → buschper → **TestFlight**: Nach 10–30 Minuten erscheint der Build. Bei „Fehlende Compliance“ → **Verwalten** → „Keine“ (die Info.plist sagt es schon, manchmal fragt Apple trotzdem). |
| ☐ | **Auf den Geräten installieren** | Beide installieren die App **TestFlight** aus dem App Store und nehmen die Einladung an (E-Mail). Danach in TestFlight → buschper → **Installieren**. |
| ☐ | **Erster Start auf dem iPhone** | Ersteinrichtung, Health-Berechtigungen **alle** erlauben, dann unter **Ig → Erinnerige** nach Wunsch einschalten. |

## Zusätzlich für den App Store (später, falls gewünscht)

| Status | Punkt | Was genau |
|---|---|---|
| ☐ | **Datenschutzerklärung veröffentlichen** | Entwurf in `PRIVACY.md`, braucht eine erreichbare URL |
| ☐ | **Support-URL** | Pflichtfeld |
| ☐ | **App-Datenschutzangaben** | App Store Connect → **App Privacy**. Gesundheitsdaten und die Abfrage bei Open Food Facts angeben |
| ☐ | **HealthKit-Begründungen** | Die Texte, warum buschper Health liest und schreibt, prüft Apple bei Gesundheits-Apps besonders genau |
| ☐ | **Keine medizinischen Aussagen** | Beschreibung und Screenshots dürfen die Schlafanalyse nicht als Diagnose darstellen |
| ☐ | **Quellenangabe BLV** | Schweizer Nährwertdatenbank gemäss Nutzungsbedingungen in der App nennen |
| ☐ | **Screenshots, Beschreibung, Kategorie** | Kategorie „Gesundheit und Fitness“ |

## Bekannte Grenzen dieser Version

- **Kein App-Icon** im Projekt – kommt von dir (siehe oben).
- **BLV-Daten** sind nicht enthalten, bis `tools/import_blv.py` gelaufen ist
  (SETUP.md Abschnitt 7b). Bis dahin: rund 110 Grundnahrungsmittel mit Richtwerten.
- **Apples eigener Schlafscore** ist für andere Apps nicht zugänglich; buschper
  rechnet einen eigenen (SPEC 11.2). Deshalb weichen die Zahlen von Apples Anzeige ab.
- **Löschen auf einem anderen Gerät:** Wird ein Eintrag auf dem iPad gelöscht, der
  auf dem iPhone erfasst wurde, bleibt sein Wert in Health stehen. Health-Werte
  schreibt und löscht immer das Gerät, auf dem der Eintrag entstanden ist.
- **Widget-Wasser** erscheint in der Tagesliste und in Health erst, wenn buschper
  das nächste Mal geöffnet wird. Die Anzeige im Widget stimmt sofort.
- **Trink-Erinnerungen** werden bei jedem Öffnen für heute und morgen geplant. Wer
  die App zwei Tage nicht öffnet, bekommt danach keine mehr, bis zum nächsten Öffnen.
- **Manuelles Training mit Uhr:** Wer beim Training die Apple Watch trägt, hat dort
  meist schon ein Training. Zusätzlich von Hand erfasst, zählen die Kalorien doppelt.
- **Schlafanalyse** braucht Zeit: Muster erscheinen erst ab 5 Nächten mit und
  5 ohne einen Faktor.

