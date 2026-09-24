#!/bin/bash
# buschper – alles Wichtige im Terminal, ohne in Xcode herumzuklicken.
#
# Aufruf (im Projektordner):
#
#   ./tools/buschper.sh setup          Team-ID eintragen, Voraussetzungen prüfen (einmalig)
#   ./tools/buschper.sh check          Strukturprüfung ohne Xcode (schnell)
#   ./tools/buschper.sh build          Für den Simulator bauen
#   ./tools/buschper.sh test           Alle Tests im Simulator laufen lassen
#   ./tools/buschper.sh run            Bauen und im Simulator starten
#   ./tools/buschper.sh device         Bauen und auf dem angeschlossenen iPhone starten
#   ./tools/buschper.sh blv DATEI      Schweizer Nährwertdatenbank importieren
#   ./tools/buschper.sh testflight     Neue Version bauen und zu TestFlight hochladen
#   ./tools/buschper.sh update         Neuste Version von GitHub holen
#
# Bei Fehlern landen die vollständigen Fehlertexte in build/errors.txt und
# zusätzlich in der Zwischenablage – einfach an Claude schicken (⌘V).

set -u
cd "$(dirname "$0")/.." || exit 1

PROJECT="buschper.xcodeproj"
SCHEME="buschper"
BUNDLE_ID="ch.hebera.buschper"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/DerivedData"
LOG="$BUILD_DIR/build.log"
ERRORS="$BUILD_DIR/errors.txt"

mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------- Hilfen

say()  { printf "\n\033[1;35m▸ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; }

team_id() {
    sed -n 's/^BUSCHPER_DEVELOPMENT_TEAM *= *\([A-Z0-9]*\).*/\1/p' Config/Signing.local.xcconfig 2>/dev/null
}

require_setup() {
    if [ ! -f Config/Signing.local.xcconfig ] || [ -z "$(team_id)" ] || [ "$(team_id)" = "ABCDE12345" ]; then
        fail "Zuerst einrichten: ./tools/buschper.sh setup"
        exit 1
    fi
}

# Erstes verfügbares iPhone im Simulator, bevorzugt das neuste Modell.
simulator_id() {
    xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys, re
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    version = tuple(int(x) for x in re.findall(r"\d+", runtime.split("iOS")[-1])[:2])
    for d in devices:
        if d.get("isAvailable") and d["name"].startswith("iPhone"):
            key = (version, "Pro" in d["name"], d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"], d["name"])
if best:
    print(best[1] + "|" + best[2])
'
}

# Fehler aus dem Log herausziehen, zeigen und in die Zwischenablage legen.
report_errors() {
    grep -E "error:|\*\* (BUILD|TEST|ARCHIVE|EXPORT) FAILED|Testing failed|✘|failed \(" "$LOG" \
        | grep -v "^note:" | sort -u > "$ERRORS"
    if [ -s "$ERRORS" ]; then
        fail "Es gab Fehler ($(wc -l < "$ERRORS" | tr -d ' ') Zeilen):"
        head -40 "$ERRORS"
        pbcopy < "$ERRORS" 2>/dev/null && echo "" && ok "Fehlertexte sind in der Zwischenablage – an Claude schicken (⌘V)."
        echo "Vollständig: $ERRORS   ·   ganzes Log: $LOG"
    else
        fail "Fehlgeschlagen, aber ohne erkennbare Fehlerzeile. Bitte das Ende des Logs schicken:"
        tail -30 "$LOG"
        tail -80 "$LOG" | pbcopy 2>/dev/null && ok "Die letzten 80 Zeilen sind in der Zwischenablage."
    fi
}

run_xcodebuild() {
    # Alles ins Log, nur eine Fortschrittsanzeige ins Terminal.
    xcodebuild "$@" > "$LOG" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf "."
        sleep 3
    done
    wait "$pid"
    local status=$?
    echo ""
    return $status
}

# ---------------------------------------------------------------- Befehle

cmd_setup() {
    say "Voraussetzungen"
    if ! xcodebuild -version >/dev/null 2>&1; then
        fail "Xcode fehlt oder ist nicht ausgewählt."
        echo "  Xcode aus dem App Store installieren, einmal öffnen, dann:"
        echo "  sudo xcode-select -s /Applications/Xcode.app"
        exit 1
    fi
    local version
    version=$(xcodebuild -version | head -1 | sed 's/Xcode //')
    if [ "${version%%.*}" -lt 26 ]; then
        fail "Xcode $version ist zu alt – es braucht Xcode 26 oder neuer."
        exit 1
    fi
    ok "Xcode $version"

    if [ -n "$(team_id)" ] && [ "$(team_id)" != "ABCDE12345" ]; then
        ok "Team-ID ist schon eingetragen: $(team_id)"
    else
        echo ""
        echo "Die Team-ID findest du unter https://developer.apple.com/account → Membership details."
        echo "Es ist dieselbe wie bei Frostify (zehn Zeichen, z. B. AB12CD34EF)."
        if [ -f ../Frostify/Config/Signing.local.xcconfig ]; then
            local frostify
            frostify=$(sed -n 's/^FROSTIFY_DEVELOPMENT_TEAM *= *\([A-Z0-9]*\).*/\1/p' ../Frostify/Config/Signing.local.xcconfig)
            [ -n "$frostify" ] && echo "Bei Frostify steht: $frostify"
        fi
        printf "Team-ID: "
        read -r team
        team=$(echo "$team" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
        if ! echo "$team" | grep -Eq '^[A-Z0-9]{10}$'; then
            fail "'$team' sieht nicht wie eine Team-ID aus (zehn Buchstaben/Ziffern)."
            exit 1
        fi
        sed "s/ABCDE12345/$team/" Config/Signing.local.xcconfig.example > Config/Signing.local.xcconfig
        ok "Team-ID gespeichert in Config/Signing.local.xcconfig (nicht im Git)"
    fi

    say "Apple-Konto in Xcode"
    if defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists >/dev/null 2>&1; then
        ok "Ein Apple-Konto ist in Xcode hinterlegt."
    else
        echo "Nicht sicher erkennbar. Das ist der einzige Schritt, der nur in Xcode geht:"
        echo "  Xcode öffnen → Settings… (⌘,) → Accounts → + → Apple ID"
        echo "Wie bei Frostify – ist es dort schon drin, ist alles gut."
    fi

    say "Strukturprüfung"
    /usr/bin/python3 tools/verify_structure.py | tail -3

    echo ""
    ok "Fertig. Weiter mit:  ./tools/buschper.sh test   und dann   ./tools/buschper.sh run"
}

cmd_check() {
    /usr/bin/python3 tools/verify_structure.py
}

cmd_build() {
    require_setup
    say "Baue für den Simulator (dauert beim ersten Mal ein paar Minuten)"
    if run_xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$DERIVED" build; then
        ok "Bauen erfolgreich"
    else
        report_errors
        exit 1
    fi
}

cmd_test() {
    require_setup
    local sim
    sim=$(simulator_id)
    if [ -z "$sim" ]; then
        fail "Kein iPhone-Simulator gefunden. In Xcode: Settings → Components → iOS herunterladen."
        exit 1
    fi
    say "Tests im Simulator ${sim#*|}"
    if run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" \
        -destination "id=${sim%%|*}" -derivedDataPath "$DERIVED"; then
        local passed
        passed=$(grep -Eo "Test run with [0-9]+ tests? (in [0-9]+ suites? )?passed" "$LOG" | tail -1)
        ok "Alle Tests grün ${passed:+– $passed}"
    else
        report_errors
        exit 1
    fi
}

cmd_run() {
    require_setup
    local sim
    sim=$(simulator_id)
    [ -z "$sim" ] && { fail "Kein iPhone-Simulator gefunden."; exit 1; }
    local udid=${sim%%|*}
    say "Baue und starte im Simulator ${sim#*|}"
    if ! run_xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "id=$udid" -derivedDataPath "$DERIVED" build; then
        report_errors
        exit 1
    fi
    local app="$DERIVED/Build/Products/Debug-iphonesimulator/buschper.app"
    xcrun simctl boot "$udid" 2>/dev/null
    open -a Simulator
    xcrun simctl install "$udid" "$app" && xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null \
        && ok "buschper läuft im Simulator" \
        || fail "Installieren im Simulator fehlgeschlagen"
}

cmd_device() {
    require_setup
    say "Suche angeschlossenes iPhone"
    local list device
    list=$(xcrun devicectl list devices 2>/dev/null)
    device=$(echo "$list" | awk '/connected|available \(paired\)/ && /iPhone/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{4}-/) {print $i; exit}}')
    if [ -z "$device" ]; then
        fail "Kein iPhone gefunden. Per Kabel anschliessen, entsperren, „Vertrauen“ bestätigen."
        echo "$list"
        exit 1
    fi
    ok "iPhone gefunden: $device"

    say "Baue für das iPhone"
    if ! run_xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "generic/platform=iOS" -derivedDataPath "$DERIVED" \
        -allowProvisioningUpdates build; then
        report_errors
        exit 1
    fi
    local app="$DERIVED/Build/Products/Debug-iphoneos/buschper.app"
    say "Installiere und starte"
    if xcrun devicectl device install app --device "$device" "$app" >/dev/null; then
        xcrun devicectl device process launch --device "$device" "$BUNDLE_ID" >/dev/null 2>&1
        ok "buschper ist auf dem iPhone"
        echo "Startet die App nicht: am iPhone Einstellungen → Allgemein → VPN & Geräteverwaltung → Entwickler-App vertrauen,"
        echo "und Einstellungen → Datenschutz & Sicherheit → Entwicklermodus einschalten."
    else
        fail "Installieren fehlgeschlagen – iPhone entsperrt? Entwicklermodus eingeschaltet?"
        exit 1
    fi
}

cmd_blv() {
    if [ $# -lt 1 ]; then
        fail "Datei fehlt. Beispiel: ./tools/buschper.sh blv ~/Downloads/Naehrwertdaten.xlsx"
        exit 1
    fi
    /usr/bin/python3 tools/import_blv.py "$1" || exit 1
    ok "Die Datei bleibt auf deinem Mac und wird ab dem nächsten Bauen mitgeliefert."
    echo "Sie stört kein 'git pull'. Nach einem neuen Clone einfach nochmals importieren."
}

cmd_testflight() {
    require_setup
    local team build_number archive export
    team=$(team_id)
    build_number=$(date +%Y%m%d%H%M)
    archive="$BUILD_DIR/buschper.xcarchive"
    export="$BUILD_DIR/export"

    if ! grep -q '"filename" : ' buschper/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json; then
        fail "Es fehlt noch das App-Icon – ohne lehnt App Store Connect den Upload ab."
        echo "  1024 × 1024 px PNG ohne Alphakanal in Xcode unter Assets → AppIcon hineinziehen."
        exit 1
    fi

    say "Archiviere Version mit Build-Nummer $build_number"
    rm -rf "$archive" "$export"
    if ! run_xcodebuild archive -project "$PROJECT" -scheme "$SCHEME" \
        -destination "generic/platform=iOS" -archivePath "$archive" \
        -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$build_number"; then
        report_errors
        exit 1
    fi
    ok "Archiv erstellt"

    cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

    say "Lade zu App Store Connect hoch"
    if run_xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" -allowProvisioningUpdates; then
        ok "Hochgeladen. In 10–30 Minuten erscheint der Build in App Store Connect → TestFlight."
        echo "Die App muss dort einmalig angelegt sein (RELEASE.md, erster Punkt)."
    else
        report_errors
        exit 1
    fi
}

cmd_update() {
    say "Hole die neuste Version"
    if git pull; then
        ok "Aktuell"
    else
        fail "git pull hat nicht geklappt – Ausgabe an Claude schicken."
        exit 1
    fi
}

# ---------------------------------------------------------------- Start

case "${1:-}" in
    setup) cmd_setup ;;
    check) cmd_check ;;
    build) cmd_build ;;
    test) cmd_test ;;
    run) cmd_run ;;
    device) cmd_device ;;
    blv) shift; cmd_blv "$@" ;;
    testflight) cmd_testflight ;;
    update) cmd_update ;;
    *)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
        ;;
esac
