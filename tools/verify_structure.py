#!/usr/bin/env python3
"""Strukturpruefung fuer buschper (uebernommen aus Frostify).

Ersetzt keinen Compiler, faengt aber genau die Fehlerklassen ab, die beim Erzeugen
eines Xcode-Projekts ohne macOS am wahrscheinlichsten sind:

  1. Klammernbilanz in allen Swift-Dateien (unter Beachtung von Kommentaren,
     Zeichenketten, mehrzeiligen Zeichenketten und String-Interpolation)
  2. Wohlgeformtheit aller XML- und JSON-Dateien
  3. project.pbxproj: Klammernbilanz und Aufloesung jeder referenzierten Objekt-ID
  4. Core-Data-Modell: jede Beziehung hat eine passende Gegenbeziehung
  5. Abgleich Modell <-> @NSManaged-Eigenschaften der NSManagedObject-Subklassen
  6. Key-Paths in @FetchRequest verweisen auf existierende Attribute
  7. Dateien, auf die Build-Einstellungen zeigen, existieren tatsaechlich
  8. Info.plist: Schluessel, die zur Laufzeit gebraucht werden, sind vorhanden –
     und keiner davon wird als INFOPLIST_KEY_* geschrieben, wo Xcode ihn
     stillschweigend verwirft

Aufruf:  python3 tools/verify_structure.py
"""

from __future__ import annotations

import json
import os
import re
import sys
import xml.dom.minidom
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBLEMS: list[str] = []
CHECKS: list[str] = []


def problem(message: str) -> None:
    PROBLEMS.append(message)


def ok(message: str) -> None:
    CHECKS.append(message)


# ---------------------------------------------------------------- Swift-Klammern

def swift_balance(text: str) -> tuple[int, int, int, str | None]:
    """Zaehlt Klammern ausserhalb von Kommentaren und Zeichenketten."""
    curly = round_ = square = 0
    i, n = 0, len(text)
    line = 1
    # Zustand: 'code' | 'line_comment' | 'block_comment' | 'string' | 'multiline'
    state = "code"
    block_depth = 0
    interpolation: list[int] = []  # offene Klammern in \( ... )

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if ch == "\n":
            line += 1

        if state == "code":
            if ch == "/" and nxt == "/":
                state = "line_comment"
                i += 2
                continue
            if ch == "/" and nxt == "*":
                state = "block_comment"
                block_depth = 1
                i += 2
                continue
            if text.startswith('"""', i):
                state = "multiline"
                i += 3
                continue
            if ch == '"':
                state = "string"
                i += 1
                continue
            if ch == "{":
                curly += 1
            elif ch == "}":
                curly -= 1
                if curly < 0:
                    return curly, round_, square, f"Zeile {line}: schliessende geschweifte Klammer zu viel"
            elif ch == "(":
                round_ += 1
                if interpolation:
                    interpolation[-1] += 1
            elif ch == ")":
                if interpolation and interpolation[-1] == 0:
                    interpolation.pop()
                    state = "string"
                    i += 1
                    continue
                round_ -= 1
                if interpolation:
                    interpolation[-1] -= 1
                if round_ < 0:
                    return curly, round_, square, f"Zeile {line}: schliessende runde Klammer zu viel"
            elif ch == "[":
                square += 1
            elif ch == "]":
                square -= 1
                if square < 0:
                    return curly, round_, square, f"Zeile {line}: schliessende eckige Klammer zu viel"
            i += 1
            continue

        if state == "line_comment":
            if ch == "\n":
                state = "code"
            i += 1
            continue

        if state == "block_comment":
            if ch == "/" and nxt == "*":
                block_depth += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_depth -= 1
                i += 2
                if block_depth == 0:
                    state = "code"
                continue
            i += 1
            continue

        if state == "string":
            if ch == "\\" and nxt == "(":
                interpolation.append(0)
                state = "code"
                i += 2
                continue
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                state = "code"
            if ch == "\n":  # einzeilige Zeichenkette darf keinen Zeilenumbruch enthalten
                return curly, round_, square, f"Zeile {line}: Zeichenkette nicht geschlossen"
            i += 1
            continue

        if state == "multiline":
            if ch == "\\" and nxt == "(":
                interpolation.append(0)
                state = "code"
                i += 2
                continue
            if ch == "\\":
                i += 2
                continue
            if text.startswith('"""', i):
                state = "code"
                i += 3
                continue
            i += 1
            continue

    if state != "code":
        return curly, round_, square, f"Datei endet im Zustand '{state}'"
    return curly, round_, square, None


def check_swift_files() -> None:
    files = sorted(ROOT.glob("buschper/**/*.swift")) + sorted(ROOT.glob("buschperTests/**/*.swift"))
    if not files:
        problem("Keine Swift-Dateien gefunden.")
        return
    for path in files:
        text = path.read_text(encoding="utf-8")
        curly, round_, square, error = swift_balance(text)
        rel = path.relative_to(ROOT)
        if error:
            problem(f"{rel}: {error}")
            continue
        if curly or round_ or square:
            problem(
                f"{rel}: Klammern unausgeglichen "
                f"(geschweift {curly:+d}, rund {round_:+d}, eckig {square:+d})"
            )
    ok(f"Klammernbilanz in {len(files)} Swift-Dateien geprueft")


# ------------------------------------------------------------------ XML und JSON

def check_xml_and_json() -> None:
    xml_suffixes = {".xml", ".entitlements", ".xcscheme", ".xcworkspacedata", ".plist", ".xccurrentversion"}
    xml_files = [p for p in ROOT.rglob("*") if p.is_file() and p.suffix in xml_suffixes and ".git" not in p.parts]
    xml_files += [p for p in ROOT.rglob("*.xcdatamodeld/*.xcdatamodel/contents") if p.is_file()]
    for path in xml_files:
        try:
            xml.dom.minidom.parse(str(path))
        except Exception as error:  # noqa: BLE001
            problem(f"{path.relative_to(ROOT)}: XML nicht wohlgeformt – {error}")
    ok(f"{len(xml_files)} XML-Dateien wohlgeformt")

    json_files = [p for p in ROOT.rglob("*.json") if ".git" not in p.parts]
    json_files += [p for p in ROOT.rglob("*.xcstrings") if ".git" not in p.parts]
    for path in json_files:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as error:  # noqa: BLE001
            problem(f"{path.relative_to(ROOT)}: JSON ungueltig – {error}")
    ok(f"{len(json_files)} JSON-Dateien gueltig")


# --------------------------------------------------------------------- pbxproj

def check_pbxproj() -> None:
    path = ROOT / "buschper.xcodeproj" / "project.pbxproj"
    if not path.exists():
        problem("project.pbxproj fehlt.")
        return
    text = path.read_text(encoding="utf-8")

    if text.count("{") != text.count("}"):
        problem(f"project.pbxproj: geschweifte Klammern unausgeglichen ({text.count('{')} auf, {text.count('}')} zu)")
    if text.count("(") != text.count(")"):
        problem(f"project.pbxproj: runde Klammern unausgeglichen ({text.count('(')} auf, {text.count(')')} zu)")

    # Definierte Objekte: "<ID> /* Kommentar */ = {" oder "<ID> = {"
    defined = set(re.findall(r"^\t\t([0-9A-F]{24})\s*(?:/\*.*?\*/\s*)?=", text, re.MULTILINE))
    referenced = set(re.findall(r"\b([0-9A-F]{24})\b", text))
    root_match = re.search(r"rootObject = ([0-9A-F]{24})", text)

    missing = sorted(referenced - defined)
    if missing:
        problem(f"project.pbxproj: referenzierte, aber nicht definierte Objekte: {', '.join(missing)}")

    unused = sorted(defined - (referenced - defined))
    _ = unused  # nur informativ, kein Fehler

    if not root_match:
        problem("project.pbxproj: rootObject fehlt.")
    elif root_match.group(1) not in defined:
        problem("project.pbxproj: rootObject zeigt auf ein nicht definiertes Objekt.")

    for section in ("PBXNativeTarget", "PBXProject", "XCConfigurationList", "XCBuildConfiguration"):
        if f"/* Begin {section} section */" not in text or f"/* End {section} section */" not in text:
            problem(f"project.pbxproj: Abschnitt {section} unvollstaendig.")

    # Synchronisierte Ordner muessen als Verzeichnis existieren
    for group_path in re.findall(r"isa = PBXFileSystemSynchronizedRootGroup;\s*path = (\w+);", text):
        if not (ROOT / group_path).is_dir():
            problem(f"project.pbxproj: synchronisierter Ordner '{group_path}' existiert nicht.")

    ok(f"project.pbxproj: {len(defined)} Objekte definiert, alle Referenzen aufloesbar")


def check_referenced_build_files() -> None:
    text = (ROOT / "buschper.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    for setting in ("CODE_SIGN_ENTITLEMENTS",):
        for value in set(re.findall(rf"{setting} = ([^;]+);", text)):
            rel = value.strip().strip('"')
            if not (ROOT / rel).exists():
                problem(f"Build-Einstellung {setting} zeigt auf '{rel}', die Datei fehlt.")
    for xcconfig in ("Config/Signing.xcconfig",):
        if not (ROOT / xcconfig).exists():
            problem(f"Referenzierte xcconfig fehlt: {xcconfig}")
    ok("Von Build-Einstellungen referenzierte Dateien vorhanden")


# ------------------------------------------------------------------- Info.plist

# Diese Schluessel kennt die automatische Info.plist-Erzeugung NICHT. Wer sie als
# INFOPLIST_KEY_* setzt, bekommt keinen Fehler – der Schluessel fehlt am Ende
# einfach in der App. Genau so ging der Hintergrundmodus fuer CloudKit verloren.
KEYS_REQUIRING_REAL_PLIST = [
    "UIBackgroundModes",
    "CKSharingSupported",
    "UTExportedTypeDeclarations",
    "CFBundleDocumentTypes",
    "CFBundleURLTypes",
    "ITSAppUsesNonExemptEncryption",
    "NSAppTransportSecurity",
    "UIApplicationShortcutItems",
]

# Was buschper zur Laufzeit tatsaechlich braucht.
REQUIRED_PLIST_KEYS = {
    "UIBackgroundModes": "ohne 'remote-notification' meldet CloudKit keine Aenderungen anderer Geraete",
    "UIUserInterfaceStyle": "Dunkel ist das einzige Erscheinungsbild",
    "UTExportedTypeDeclarations": "ohne den Dateityp oeffnet iOS geteilte .buschper-Dateien nicht mit buschper",
    "CFBundleDocumentTypes": "ohne diesen Eintrag bietet iOS buschper fuer .buschper-Dateien nicht an",
    "CFBundleURLTypes": "ohne das Schema buschper:// oeffnet ein gescannter QR-Code die App nicht",
}

# Texte, die iOS vor dem Zugriff zeigt. Fehlt einer, stuerzt die App beim Zugriff ab.
REQUIRED_USAGE_DESCRIPTIONS = [
    "INFOPLIST_KEY_NSCameraUsageDescription",
    "INFOPLIST_KEY_NSHealthShareUsageDescription",
    "INFOPLIST_KEY_NSHealthUpdateUsageDescription",
]


def check_info_plist() -> None:
    plist_path = ROOT / "Config" / "Info.plist"
    pbx = (ROOT / "buschper.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")

    if not plist_path.exists():
        problem("Config/Info.plist fehlt.")
        return

    try:
        document = xml.dom.minidom.parse(str(plist_path))
    except Exception as error:  # noqa: BLE001
        problem(f"Config/Info.plist ist nicht wohlgeformt – {error}")
        return

    keys = {node.firstChild.data for node in document.getElementsByTagName("key") if node.firstChild}

    for key, why in REQUIRED_PLIST_KEYS.items():
        if key not in keys:
            problem(f"Config/Info.plist: '{key}' fehlt – {why}.")

    if "UIBackgroundModes" in keys and "remote-notification" not in plist_path.read_text(encoding="utf-8"):
        problem("Config/Info.plist: UIBackgroundModes enthaelt 'remote-notification' nicht.")

    for key in KEYS_REQUIRING_REAL_PLIST:
        if f"INFOPLIST_KEY_{key}" in pbx:
            problem(
                f"project.pbxproj: INFOPLIST_KEY_{key} wird von Xcode nicht ausgewertet – "
                "dieser Schluessel gehoert in Config/Info.plist."
            )

    if "INFOPLIST_FILE = Config/Info.plist;" not in pbx:
        problem("project.pbxproj: INFOPLIST_FILE zeigt nicht auf Config/Info.plist.")
    elif pbx.count("INFOPLIST_FILE = Config/Info.plist;") < 2:
        problem("project.pbxproj: INFOPLIST_FILE fehlt in einer der beiden Build-Konfigurationen.")

    for key in REQUIRED_USAGE_DESCRIPTIONS:
        if pbx.count(f"{key} = ") < 2:
            problem(f"project.pbxproj: {key} fehlt in einer der beiden Build-Konfigurationen – Absturz beim Zugriff.")

    entitlements = (ROOT / "Config" / "buschper.entitlements").read_text(encoding="utf-8")
    for key in ("aps-environment", "com.apple.developer.icloud-services", "com.apple.developer.healthkit",
                "com.apple.security.application-groups", "iCloud.ch.hebera.buschper", "group.ch.hebera.buschper"):
        if key not in entitlements:
            problem(f"Config/buschper.entitlements: '{key}' fehlt.")

    persistence = (ROOT / "buschper" / "Persistence" / "PersistenceController.swift").read_text(encoding="utf-8")
    for identifier in ("iCloud.ch.hebera.buschper", "group.ch.hebera.buschper"):
        if identifier not in persistence:
            problem(f"PersistenceController.swift: '{identifier}' stimmt nicht mit den Entitlements ueberein.")

    ok("Info.plist und Entitlements enthalten die Laufzeit-Schluessel")


# ------------------------------------------------------------------- Core Data

def load_model() -> dict[str, dict]:
    contents = list(ROOT.glob("buschper/**/*.xcdatamodeld/*.xcdatamodel/contents"))
    if not contents:
        problem("Core-Data-Modell nicht gefunden.")
        return {}
    document = xml.dom.minidom.parse(str(contents[0]))
    entities: dict[str, dict] = {}
    for entity in document.getElementsByTagName("entity"):
        name = entity.getAttribute("name")
        entities[name] = {
            "class": entity.getAttribute("representedClassName"),
            "attributes": {
                a.getAttribute("name"): {
                    "type": a.getAttribute("attributeType"),
                    "optional": a.getAttribute("optional") == "YES",
                    "default": a.getAttribute("defaultValueString"),
                }
                for a in entity.getElementsByTagName("attribute")
            },
            "relationships": {
                r.getAttribute("name"): {
                    "destination": r.getAttribute("destinationEntity"),
                    "inverseName": r.getAttribute("inverseName"),
                    "inverseEntity": r.getAttribute("inverseEntity"),
                    "toMany": r.getAttribute("toMany") == "YES",
                }
                for r in entity.getElementsByTagName("relationship")
            },
        }
    return entities


def check_model_integrity(entities: dict[str, dict]) -> None:
    if not entities:
        return
    for name, entity in entities.items():
        for rel_name, rel in entity["relationships"].items():
            destination = rel["destination"]
            if destination not in entities:
                problem(f"Modell: {name}.{rel_name} zeigt auf unbekannte Entitaet '{destination}'.")
                continue
            inverse = entities[destination]["relationships"].get(rel["inverseName"])
            if inverse is None:
                problem(f"Modell: {name}.{rel_name} nennt Gegenbeziehung '{rel['inverseName']}', die es in {destination} nicht gibt.")
                continue
            if inverse["destination"] != name:
                problem(f"Modell: Gegenbeziehung {destination}.{rel['inverseName']} zeigt nicht zurueck auf {name}.")

        # CloudKit verlangt: jedes Attribut optional oder mit Standardwert
        for attr_name, attr in entity["attributes"].items():
            if not attr["optional"] and attr["default"] == "":
                problem(
                    f"Modell: {name}.{attr_name} ist weder optional noch hat es einen Standardwert – "
                    "CloudKit lehnt das ab."
                )
    ok(f"Core-Data-Modell: {len(entities)} Entitaeten, Gegenbeziehungen und CloudKit-Regeln geprueft")


def check_managed_properties(entities: dict[str, dict]) -> None:
    """Gleicht @NSManaged-Eigenschaften mit dem Modell ab – in beide Richtungen."""
    if not entities:
        return
    by_class = {entity["class"]: (name, entity) for name, entity in entities.items() if entity["class"]}

    for path in sorted(ROOT.glob("buschper/Model/Entities/*.swift")):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        class_match = re.search(r"final class (\w+): NSManagedObject", text)
        if not class_match:
            problem(f"{rel}: keine NSManagedObject-Subklasse gefunden.")
            continue
        class_name = class_match.group(1)
        if class_name not in by_class:
            problem(f"{rel}: Klasse '{class_name}' hat keine Entsprechung im Modell.")
            continue

        entity_name, entity = by_class[class_name]
        known = set(entity["attributes"]) | set(entity["relationships"])

        # Nur die Eigenschaften der Klasse selbst, nicht die der Extensions mit Zubehoer
        body = text.split("extension ")[0]
        declared = set(re.findall(r"@NSManaged\s+(?:public\s+)?var (\w+):", body))

        for prop in sorted(declared - known):
            problem(f"{rel}: '{prop}' ist @NSManaged, fehlt aber in der Entitaet {entity_name}.")
        for prop in sorted(known - declared):
            problem(f"Modell: {entity_name}.{prop} hat keine @NSManaged-Entsprechung in {class_name}.")

        if f"@objc({class_name})" not in text:
            problem(f"{rel}: @objc({class_name}) fehlt – Core Data findet die Klasse sonst nicht zuverlaessig.")

    ok("NSManagedObject-Subklassen decken sich mit dem Modell")


def check_keypaths(entities: dict[str, dict]) -> None:
    if not entities:
        return
    by_class = {entity["class"]: entity for entity in entities.values() if entity["class"]}
    pattern = re.compile(r"\\(\w+)\.(\w+)")
    checked = 0
    for path in sorted(ROOT.glob("buschper/**/*.swift")):
        text = path.read_text(encoding="utf-8")
        for class_name, prop in pattern.findall(text):
            if class_name not in by_class:
                continue
            known = set(by_class[class_name]["attributes"]) | set(by_class[class_name]["relationships"])
            checked += 1
            if prop not in known:
                problem(f"{path.relative_to(ROOT)}: Key-Path \\{class_name}.{prop} gibt es im Modell nicht.")
    ok(f"{checked} Key-Paths auf Modell-Eigenschaften geprueft")


def check_predicates(entities: dict[str, dict]) -> None:
    """Prueft Feldnamen in NSPredicate- und NSSortDescriptor-Zeichenketten."""
    if not entities:
        return
    all_props: set[str] = set()
    for entity in entities.values():
        all_props |= set(entity["attributes"]) | set(entity["relationships"])

    sort_pattern = re.compile(r'NSSortDescriptor\(key: "(\w+)"')
    predicate_pattern = re.compile(r'NSPredicate\(format: "([^"]+)"')
    for path in sorted(ROOT.glob("buschper/**/*.swift")):
        text = path.read_text(encoding="utf-8")
        for key in sort_pattern.findall(text):
            if key not in all_props:
                problem(f"{path.relative_to(ROOT)}: Sortierschluessel '{key}' gibt es im Modell nicht.")
        for fmt in predicate_pattern.findall(text):
            for token in re.findall(r"\b([a-z][A-Za-z0-9]*)\b", fmt):
                if token in {"nil", "AND", "OR", "NOT", "and", "or", "not", "c", "d"}:
                    continue
                if token not in all_props:
                    problem(f"{path.relative_to(ROOT)}: Feld '{token}' im Praedikat gibt es im Modell nicht.")
    ok("Praedikate und Sortierschluessel gegen das Modell geprueft")


# ------------------------------------------------------------------------ Start

def main() -> int:
    check_swift_files()
    check_xml_and_json()
    check_pbxproj()
    check_referenced_build_files()
    check_info_plist()
    entities = load_model()
    check_model_integrity(entities)
    check_managed_properties(entities)
    check_keypaths(entities)
    check_predicates(entities)

    print("buschper – Strukturpruefung\n")
    for line in CHECKS:
        print(f"  [ok] {line}")
    if PROBLEMS:
        print("\nGefundene Probleme:\n")
        for line in PROBLEMS:
            print(f"  [!!] {line}")
        print(f"\n{len(PROBLEMS)} Problem(e). Das ersetzt keinen Compiler – der Build-Nachweis liegt in Xcode.")
        return 1
    print("\nKeine strukturellen Probleme gefunden.")
    print("Wichtig: Das ist kein Compiler. Den Build-Nachweis liefert erst Xcode (Cmd+B).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
