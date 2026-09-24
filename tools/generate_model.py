#!/usr/bin/env python3
"""Erzeugt das Core-Data-Modell und die NSManagedObject-Klassen aus EINER Definition.

Warum: Modell (XML) und @NSManaged-Eigenschaften muessen exakt uebereinstimmen.
Von Hand gepflegt laufen sie frueher oder spaeter auseinander. Dieses Skript ist
die einzige Quelle. Nach einer Aenderung:

    python3 tools/generate_model.py

Erzeugt:
  buschper/Model/buschper.xcdatamodeld/…            (Modell)
  buschper/Model/Entities/<Entitaet>.swift           (nur @NSManaged, nicht von Hand aendern)

Bequeme Zugriffe gehoeren nach buschper/Model/EntityExtensions/.

CloudKit-Regeln, die hier eingehalten werden: jedes Attribut optional, Skalare mit
Standardwert, keine Eindeutigkeitsregeln, jede Beziehung optional mit Gegenbeziehung.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = ROOT / "buschper" / "Model" / "buschper.xcdatamodeld"
ENTITY_DIR = ROOT / "buschper" / "Model" / "Entities"

# Typ -> (Core-Data-Typ, Swift-Typ, Standardwert oder None, skalar)
TYPES = {
    "uuid":   ("UUID", "UUID?", None, False),
    "string": ("String", "String?", "", False),
    "date":   ("Date", "Date?", None, False),
    "double": ("Double", "Double", "0.0", True),
    "int32":  ("Integer 32", "Int32", "0", True),
    "int16":  ("Integer 16", "Int16", "0", True),
    "bool":   ("Boolean", "Bool", "NO", True),
}

# (Name, Typ, Standardwert-Ueberschreibung)
ENTITIES = {
    "Profile": {
        "doc": "Profil und Ziele. Es gibt genau eines (SPEC 4).",
        "attributes": [
            ("id", "uuid"), ("sexRaw", "string", "male"), ("birthDate", "date"),
            ("heightCm", "double", "175.0"), ("goalRaw", "string", "maintain"),
            ("offsetLose", "double", "-500.0"), ("offsetMaintain", "double", "0.0"),
            ("offsetGain", "double", "300.0"),
            ("carbsPercent", "double", "45.0"), ("proteinPercent", "double", "25.0"),
            ("fatPercent", "double", "30.0"), ("fiberMinG", "double", "30.0"),
            ("activityProfileRaw", "string", "light"),
            ("sleepGoalMinutes", "int32", "480"), ("stepGoal", "int32", "10000"),
            ("waterGoalOverrideMl", "double"), ("targetWeightKg", "double"),
            ("fallbackWeightKg", "double", "75.0"),
            ("dashboardLayoutJSON", "string"), ("factorThresholdsJSON", "string"),
            ("badNightRulesJSON", "string"), ("onboardingCompleted", "bool"),
            ("createdAt", "date"), ("updatedAt", "date"),
        ],
        "relationships": [],
    },
    "FoodProduct": {
        "doc": "Eigenes Produkt oder korrigierte Kopie eines fremden (SPEC 5.5).",
        "attributes": [
            ("id", "uuid"), ("name", "string"), ("brand", "string"), ("barcode", "string"),
            ("isLiquid", "bool"), ("originRaw", "string", "own"), ("originExternalId", "string"),
            ("nutrientsJSON", "string"), ("isFavorite", "bool"), ("useCount", "int32"),
            ("lastUsedAt", "date"), ("createdAt", "date"), ("updatedAt", "date"),
        ],
        "relationships": [
            ("portions", "PortionSize", "product", True, "Cascade"),
        ],
    },
    "PortionSize": {
        "doc": "Eigene Portionsgroesse eines Produkts, z. B. 1 Schiibe = 30 g.",
        "attributes": [("id", "uuid"), ("name", "string"), ("grams", "double"), ("sortIndex", "int32")],
        "relationships": [("product", "FoodProduct", "portions", False, "Nullify")],
    },
    "ExternalFoodRef": {
        "doc": "Gemerktes fremdes Produkt (BLV oder Open Food Facts) fuer Favoriten und Zletscht bruucht.",
        "attributes": [
            ("id", "uuid"), ("sourceRaw", "string", "off"), ("externalId", "string"),
            ("name", "string"), ("brand", "string"), ("isLiquid", "bool"),
            ("nutrientsJSON", "string"), ("isFavorite", "bool"), ("useCount", "int32"),
            ("lastUsedAt", "date"),
        ],
        "relationships": [],
    },
    "Recipe": {
        "doc": "Rezept mit Zutaten und Portionen (SPEC 5.7).",
        "attributes": [
            ("id", "uuid"), ("name", "string"), ("servings", "double", "1.0"), ("note", "string"),
            ("isFavorite", "bool"), ("useCount", "int32"), ("lastUsedAt", "date"),
            ("createdAt", "date"), ("updatedAt", "date"),
        ],
        "relationships": [("ingredients", "RecipeIngredient", "recipe", True, "Cascade")],
    },
    "RecipeIngredient": {
        "doc": "Zutat mit Menge und Naehrwert-Snapshot pro 100 g/ml.",
        "attributes": [
            ("id", "uuid"), ("name", "string"), ("amountG", "double"), ("isLiquid", "bool"),
            ("nutrientsJSON", "string"), ("sourceKindRaw", "string"), ("sourceId", "string"),
            ("sortIndex", "int32"),
        ],
        "relationships": [("recipe", "Recipe", "ingredients", False, "Nullify")],
    },
    "Meal": {
        "doc": "Mahlzeit: Zeitpunkt, Kategorie und Eintraege (SPEC 5.2).",
        "attributes": [
            ("id", "uuid"), ("timestamp", "date"), ("categoryRaw", "string", "snack"),
            ("title", "string"), ("createdAt", "date"), ("updatedAt", "date"),
        ],
        "relationships": [("entries", "FoodEntry", "meal", True, "Cascade")],
    },
    "FoodEntry": {
        "doc": "Geloggter Eintrag mit festem Naehrwert-Snapshot (SPEC 5.9).",
        "attributes": [
            ("id", "uuid"), ("name", "string"), ("amount", "double"), ("unitLabel", "string"),
            ("grams", "double"), ("isLiquid", "bool"), ("nutrientsJSON", "string"),
            ("kindRaw", "string", "product"), ("sourceId", "string"), ("servings", "double"),
            ("sortIndex", "int32"),
        ],
        "relationships": [("meal", "Meal", "entries", False, "Nullify")],
    },
    "DrinkEntry": {
        "doc": "Getraenk (SPEC 7).",
        "attributes": [
            ("id", "uuid"), ("timestamp", "date"), ("drinkTypeRaw", "string", "water"),
            ("name", "string"), ("volumeMl", "double"), ("countsAsFluid", "bool", "YES"),
            ("abvPercent", "double"), ("nutrientsJSON", "string"), ("presetId", "string"),
            ("createdAt", "date"), ("updatedAt", "date"),
        ],
        "relationships": [],
    },
    "DrinkPreset": {
        "doc": "Eigene Getraenkevorlage, z. B. Cappuccino 2 dl.",
        "attributes": [
            ("id", "uuid"), ("name", "string"), ("drinkTypeRaw", "string", "custom"),
            ("volumeMl", "double", "250.0"), ("abvPercent", "double"),
            ("nutrientsJSON", "string"), ("sortIndex", "int32"),
        ],
        "relationships": [],
    },
    "WorkoutEntry": {
        "doc": "Manuelles Training (SPEC 10.2).",
        "attributes": [
            ("id", "uuid"), ("start", "date"), ("durationMinutes", "double", "30.0"),
            ("sportTypeRaw", "string", "other"), ("intensityRaw", "string", "moderate"),
            ("kcal", "double"), ("kcalIsManual", "bool"), ("note", "string"),
            ("createdAt", "date"), ("updatedAt", "date"),
        ],
        "relationships": [],
    },
    "WeightEntry": {
        "doc": "Manuell erfasstes Gewicht (SPEC 9).",
        "attributes": [("id", "uuid"), ("timestamp", "date"), ("kg", "double"), ("createdAt", "date")],
        "relationships": [],
    },
    "NightRecord": {
        "doc": "Ausgewertete Nacht mit Vortagskennzahlen und Faktoren (SPEC 12.2).",
        "attributes": [
            ("id", "uuid"), ("nightDate", "date"), ("score", "double"), ("componentsJSON", "string"),
            ("asleepMinutes", "double"), ("deepMinutes", "double"), ("remMinutes", "double"),
            ("coreMinutes", "double"), ("awakeMinutes", "double"), ("hasStages", "bool"),
            ("sleepOnset", "date"), ("wakeTime", "date"), ("rating", "int16"),
            ("isBad", "bool"), ("badReasonsJSON", "string"), ("factorsJSON", "string"),
            ("dayMetricsJSON", "string"), ("note", "string"), ("tagsJSON", "string"),
            ("excluded", "bool"), ("computedAt", "date"),
        ],
        "relationships": [],
    },
    "IgnoredHealthSample": {
        "doc": "Fremder Health-Wert, der nicht beruecksichtigt werden soll (SPEC 8.3).",
        "attributes": [("id", "uuid"), ("sampleUUID", "string"), ("kindRaw", "string"), ("ignoredAt", "date")],
        "relationships": [],
    },
    "HealthLink": {
        "doc": "Verbindet einen eigenen Eintrag mit seinen Werten in Apple Health (SPEC 8.3).",
        "attributes": [
            ("id", "uuid"), ("localId", "uuid"), ("localKindRaw", "string"),
            ("sampleUUIDs", "string"), ("deviceId", "string"), ("pendingWrite", "bool"),
            ("pendingDelete", "bool"), ("updatedAt", "date"),
        ],
        "relationships": [],
    },
}


def model_xml() -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" '
        'lastSavedToolsVersion="23504" systemVersion="25A000" minimumToolsVersion="Automatic" '
        'sourceLanguage="Swift" usedWithCloudKit="YES" userDefinedModelVersionIdentifier="">',
    ]
    for name in sorted(ENTITIES):
        entity = ENTITIES[name]
        lines.append(f'    <entity name="{name}" representedClassName="{name}" syncable="YES">')
        for attr in sorted(entity["attributes"], key=lambda a: a[0]):
            attr_name, kind = attr[0], attr[1]
            cd_type, _, default, scalar = TYPES[kind]
            if len(attr) > 2:
                default = attr[2]
            parts = [f'name="{attr_name}"', 'optional="YES"', f'attributeType="{cd_type}"']
            if default is not None:
                parts.append(f'defaultValueString="{default}"')
            if kind in ("uuid", "date"):
                parts.append('usesScalarValueType="NO"')
            elif scalar:
                parts.append('usesScalarValueType="YES"')
            lines.append(f'        <attribute {" ".join(parts)}/>')
        for rel_name, dest, inverse, to_many, rule in sorted(entity["relationships"]):
            many = ' toMany="YES"' if to_many else ' maxCount="1"'
            lines.append(
                f'        <relationship name="{rel_name}" optional="YES"{many} deletionRule="{rule}" '
                f'destinationEntity="{dest}" inverseName="{inverse}" inverseEntity="{dest}"/>'
            )
        lines.append("    </entity>")
    lines.append("</model>")
    return "\n".join(lines) + "\n"


def entity_swift(name: str) -> str:
    entity = ENTITIES[name]
    out = [
        "import CoreData",
        "import Foundation",
        "",
        "// Erzeugt von tools/generate_model.py – nicht von Hand aendern.",
        "// Bequeme Zugriffe stehen in Model/EntityExtensions/.",
        "",
        f"/// {entity['doc']}",
        f"@objc({name})",
        f"final class {name}: NSManagedObject {{",
        f"    @nonobjc class func fetchRequest() -> NSFetchRequest<{name}> {{",
        f'        NSFetchRequest<{name}>(entityName: "{name}")',
        "    }",
        "",
    ]
    for attr in entity["attributes"]:
        _, swift_type, _, _ = TYPES[attr[1]]
        out.append(f"    @NSManaged var {attr[0]}: {swift_type}")
    for rel_name, _, _, to_many, _ in entity["relationships"]:
        swift_type = "NSSet?" if to_many else f"{ENTITIES_REL_TYPE(rel_name, name)}?"
        out.append(f"    @NSManaged var {rel_name}: {swift_type}")
    out.append("}")
    return "\n".join(out) + "\n"


def ENTITIES_REL_TYPE(rel_name: str, owner: str) -> str:  # noqa: N802
    for rel in ENTITIES[owner]["relationships"]:
        if rel[0] == rel_name:
            return rel[1]
    raise KeyError(rel_name)


def main() -> None:
    model_path = MODEL_DIR / "buschper.xcdatamodel"
    model_path.mkdir(parents=True, exist_ok=True)
    (model_path / "contents").write_text(model_xml(), encoding="utf-8")
    (MODEL_DIR / ".xccurrentversion").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n\t<key>_XCCurrentVersionName</key>\n'
        '\t<string>buschper.xcdatamodel</string>\n</dict>\n</plist>\n',
        encoding="utf-8",
    )
    ENTITY_DIR.mkdir(parents=True, exist_ok=True)
    for old in ENTITY_DIR.glob("*.swift"):
        old.unlink()
    for name in ENTITIES:
        (ENTITY_DIR / f"{name}.swift").write_text(entity_swift(name), encoding="utf-8")
    print(f"{len(ENTITIES)} Entitaeten erzeugt.")


if __name__ == "__main__":
    main()
