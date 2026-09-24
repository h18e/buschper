#!/usr/bin/env python3
"""Wandelt die Schweizer Naehrwertdatenbank (BLV) in die Datei um, die buschper mitliefert.

Warum ein Skript statt fertiger Daten: Die Umgebung, in der buschper entsteht,
darf naehrwertdaten.ch nicht erreichen. Du laedst die Datei einmal selbst herunter,
dieses Skript macht den Rest – ohne Zusatzpakete, mit dem Python, das macOS
mitbringt.

1. https://naehrwertdaten.ch → Downloads → „Schweizer Nährwertdatenbank“ als
   Excel (.xlsx) oder CSV herunterladen
2. Im Terminal, im Projektordner:

       python3 tools/import_blv.py ~/Downloads/<Dateiname>.xlsx

3. Es entsteht buschper/Resources/blv_foods.json. Ab dem naechsten Build sucht
   buschper darin statt in der Richtwert-Liste.

Die Spalten werden an ihren Namen erkannt. Findet das Skript eine Pflichtspalte
nicht, bricht es mit einer Liste aller gefundenen Spalten ab – die bitte an
Claude schicken.

Nutzungsbedingungen: Die Daten sind frei verwendbar mit Quellenangabe
(„Schweizer Nährwertdatenbank, BLV“). buschper nennt die Quelle unter
Ig → Über buschper und bei jedem Treffer.
"""

from __future__ import annotations

import csv
import json
import re
import sys
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "buschper" / "Resources" / "blv_foods.json"

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text or "").encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", text).strip().lower()


# ------------------------------------------------------------------ Einlesen

def read_xlsx(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        shared: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in root.findall("m:si", NS):
                shared.append("".join(node.text or "" for node in item.iter(f"{{{NS['m']}}}t")))
        sheets = sorted(n for n in archive.namelist() if n.startswith("xl/worksheets/sheet"))
        if not sheets:
            sys.exit("Die Excel-Datei enthaelt kein Tabellenblatt.")
        # Das Blatt mit den meisten Zeilen ist das mit den Lebensmitteln.
        best: list[list[str]] = []
        for sheet in sheets:
            rows = parse_sheet(archive.read(sheet), shared)
            if len(rows) > len(best):
                best = rows
        return best


def column_index(reference: str) -> int:
    letters = re.match(r"[A-Z]+", reference).group(0)
    index = 0
    for letter in letters:
        index = index * 26 + (ord(letter) - 64)
    return index - 1


def parse_sheet(data: bytes, shared: list[str]) -> list[list[str]]:
    root = ET.fromstring(data)
    rows: list[list[str]] = []
    for row in root.iter(f"{{{NS['m']}}}row"):
        values: dict[int, str] = {}
        for cell in row.findall("m:c", NS):
            ref = cell.get("r", "A1")
            kind = cell.get("t")
            value_node = cell.find("m:v", NS)
            if kind == "s" and value_node is not None:
                text = shared[int(value_node.text)]
            elif kind == "inlineStr":
                text = "".join(node.text or "" for node in cell.iter(f"{{{NS['m']}}}t"))
            else:
                text = value_node.text if value_node is not None else ""
            values[column_index(ref)] = text or ""
        if values:
            width = max(values) + 1
            rows.append([values.get(i, "") for i in range(width)])
    return rows


def read_csv(path: Path) -> list[list[str]]:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "cp1252", "latin-1"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    dialect = csv.Sniffer().sniff(text[:5000], delimiters=";,\t")
    return [row for row in csv.reader(text.splitlines(), dialect)]


# ------------------------------------------------------------------ Spalten

REQUIRED = ("name", "kcal")

# Erkennungsregeln: alle Woerter muessen im (normalisierten) Spaltennamen stehen.
RULES = {
    "id": [["id"]],
    "name": [["name"]],
    "category": [["kategorie"]],
    "unit": [["bezug"], ["referenzeinheit"], ["einheit"]],
    "kcal": [["energie", "kcal"], ["energy", "kcal"]],
    "carbs": [["kohlenhydrate", "verfugbar"], ["kohlenhydrate"]],
    "sugar": [["zucker"]],
    "fat": [["fett", "total"], ["fett"]],
    "saturatedFat": [["fettsauren", "gesattigt"]],
    "protein": [["protein"], ["eiweiss"]],
    "fiber": [["nahrungsfasern"], ["ballaststoffe"]],
    "salt": [["salz"]],
    "alcohol": [["alkohol"]],
}

# Nebenspalten, die denselben Naehrwert nennen, aber keine Werte enthalten.
SIDE_COLUMNS = ("ableitung", "quelle", "herleitung", "matrix", "datenquelle", "source", "derivation")


def find_header(rows: list[list[str]]) -> int:
    for index, row in enumerate(rows[:30]):
        cells = [normalize(c) for c in row]
        if any(c == "name" or c.startswith("name ") for c in cells) and any("kcal" in c for c in cells):
            return index
    sys.exit("Keine Kopfzeile mit 'Name' und 'kcal' gefunden. Ist das die richtige Datei?")


def map_columns(header: list[str]) -> dict[str, int]:
    normalized = [normalize(h) for h in header]
    mapping: dict[str, int] = {}
    for key, alternatives in RULES.items():
        for words in alternatives:
            for index, name in enumerate(normalized):
                if index in mapping.values():
                    continue
                if any(side in name for side in SIDE_COLUMNS):
                    continue
                if key == "fat" and "fettsauren" in name:
                    continue
                if key == "name" and not (name == "name" or name.startswith("name ")):
                    continue
                if key == "id" and not (name == "id" or name.startswith("id ")):
                    continue
                if all(word in name for word in words):
                    mapping[key] = index
                    break
            if key in mapping:
                break
    return mapping


def number(text: str) -> float | None:
    value = (text or "").strip().lower().replace(",", ".")
    if value in ("", "n.d.", "nd", "-", "–"):
        return None
    if value.startswith("sp"):  # Spuren
        return 0.0
    if value.startswith("<"):  # unter der Nachweisgrenze
        return 0.0
    try:
        return round(float(value), 2)
    except ValueError:
        return None


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", normalize(text)).strip("-")


# ------------------------------------------------------------------ Start

def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1]).expanduser()
    if not source.exists():
        sys.exit(f"Datei nicht gefunden: {source}")

    rows = read_xlsx(source) if source.suffix.lower() in (".xlsx", ".xlsm") else read_csv(source)
    header_index = find_header(rows)
    header = rows[header_index]
    mapping = map_columns(header)

    print("Erkannte Spalten:")
    for key in RULES:
        where = f"'{header[mapping[key]]}'" if key in mapping else "— nicht gefunden"
        print(f"  {key:13} {where}")

    missing = [key for key in REQUIRED if key not in mapping]
    if missing:
        print("\nAlle Spalten der Datei:")
        for index, name in enumerate(header):
            print(f"  {index:3}: {name}")
        sys.exit(f"\nPflichtspalte(n) fehlen: {', '.join(missing)}. Bitte diese Ausgabe an Claude schicken.")

    items = []
    seen: set[str] = set()
    for row in rows[header_index + 1:]:
        def cell(key: str) -> str:
            index = mapping.get(key)
            return row[index] if index is not None and index < len(row) else ""

        name = cell("name").strip()
        kcal = number(cell("kcal"))
        if not name or kcal is None:
            continue
        per100 = {"kcal": kcal}
        for key in ("carbs", "sugar", "fat", "saturatedFat", "protein", "fiber", "salt", "alcohol"):
            value = number(cell(key))
            if value is not None:
                per100[key] = value
        identifier = "blv-" + (slug(cell("id")) or slug(name))
        while identifier in seen:
            identifier += "-x"
        seen.add(identifier)
        unit = normalize(cell("unit"))
        items.append({
            "id": identifier,
            "name": name,
            "liquid": "ml" in unit,
            "category": cell("category").strip() or None,
            "per100": per100,
        })

    if len(items) < 100:
        sys.exit(f"Nur {len(items)} Lebensmittel erkannt – das ist zu wenig. Bitte Ausgabe an Claude schicken.")

    document = {
        "source": "blv",
        "description": "Schweizer Naehrwertdatenbank, Bundesamt fuer Lebensmittelsicherheit und Veterinaerwesen (BLV), naehrwertdaten.ch",
        "items": items,
    }
    OUTPUT.write_text(json.dumps(document, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"\n{len(items)} Lebensmittel nach {OUTPUT.relative_to(ROOT)} geschrieben.")
    print("Jetzt in Xcode neu bauen (Cmd+R). Danach kommt die Suche aus der BLV-Datenbank.")


if __name__ == "__main__":
    main()
