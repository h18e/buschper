# buschper – Checkliste vor einer Verteilung

Alles hier kann nur ein Mensch erledigen: Es braucht Zugang zu App Store Connect,
zum Apple-Entwicklerportal oder eine gestalterische Entscheidung. Den Status bitte
laufend nachführen. Die Liste wird während der Umsetzung ergänzt.

## TestFlight (für dich und deine Partnerin)

| Status | Punkt | Was genau |
|---|---|---|
| ☐ | **App in App Store Connect anlegen** | https://appstoreconnect.apple.com → **Apps** → **+** → **Neue App**, Bundle ID `ch.hebera.buschper` |
| ☐ | **Partnerin als interne Testerin** | App Store Connect → **Benutzer und Zugriff** → **+** → ihre Apple-ID einladen, Rolle z. B. **Marketing** oder **Kundensupport**. Danach in der App unter **TestFlight → Interne Tests** hinzufügen. Interne Tester brauchen **keine** Beta-Prüfung durch Apple. |
| ☐ | **CloudKit-Schema nach Production** | https://icloud.developer.apple.com/dashboard → Container `iCloud.ch.hebera.buschper` → **Deploy Schema to Production**. Ohne diesen Schritt gleicht die TestFlight-Version nichts ab. |
| ☐ | **aps-environment auf production** | In der Entitlements-Datei muss für TestFlight `production` stehen. |
| ☐ | **Versionsnummer** | Jede hochgeladene Version braucht eine neue Build-Nummer. |
| ☐ | **Export-Compliance** | buschper nutzt nur die Standardverschlüsselung von iOS. In der Regel: „Verwendet keine nicht-exemptierte Verschlüsselung“. |
| ☐ | **App-Icon** | 1024 × 1024 px PNG, **kein Alphakanal**, randlos, sRGB. |

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
