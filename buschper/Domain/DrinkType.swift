import Foundation

/// Getränketypen mit den Regeln aus SPEC 7.2.
///
/// Die Nährwerte hier sind **Richtwerte pro 100 ml**, die beim Erfassen als Vorschlag
/// dienen. Wer es genauer weiss, überschreibt sie oder legt eine eigene Vorlage an.
enum DrinkType: String, Codable, CaseIterable, Identifiable {
    case water
    case mineral
    case tea
    case coffee
    case milk
    case juice
    case softDrink
    case beer
    case wine
    case spirits
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .water: return "Wasser"
        case .mineral: return "Mineral"
        case .tea: return "Tee"
        case .coffee: return "Kafi"
        case .milk: return "Milch"
        case .juice: return "Saft"
        case .softDrink: return "Süessgetränk"
        case .beer: return "Bier"
        case .wine: return "Wy"
        case .spirits: return "Schnaps"
        case .custom: return "Eigets"
        }
    }

    var symbolName: String {
        switch self {
        case .water: return "drop.fill"
        case .mineral: return "bubbles.and.sparkles.fill"
        case .tea: return "leaf.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .milk: return "waterbottle.fill"
        case .juice: return "carrot.fill"
        case .softDrink: return "takeoutbag.and.cup.and.straw.fill"
        case .beer: return "mug.fill"
        case .wine: return "wineglass.fill"
        case .spirits: return "flame.fill"
        case .custom: return "cup.and.heat.waves.fill"
        }
    }

    var isAlcoholic: Bool {
        switch self {
        case .beer, .wine, .spirits: return true
        default: return false
        }
    }

    /// Alkoholische Getränke zählen nicht zur Flüssigkeit, alles andere voll (Q13).
    var countsAsFluidByDefault: Bool { !isAlcoholic }

    /// Übliche Menge in ml als Vorschlag.
    var defaultVolumeMl: Double {
        switch self {
        case .water, .mineral, .tea, .juice, .softDrink, .milk, .custom: return 250
        case .coffee: return 150
        case .beer: return 500
        case .wine: return 100
        case .spirits: return 20
        }
    }

    /// Vol-% als Vorschlag.
    var defaultABV: Double {
        switch self {
        case .beer: return 5
        case .wine: return 12.5
        case .spirits: return 40
        default: return 0
        }
    }

    /// Richtwerte pro 100 ml – ohne Alkohol, der wird aus Vol-% berechnet.
    var defaultNutrientsPer100ml: Nutrients {
        switch self {
        case .water, .mineral:
            return Nutrients(kcal: 0)
        case .tea:
            return Nutrients(kcal: 1, caffeine: 20)
        case .coffee:
            return Nutrients(kcal: 2, caffeine: 55)
        case .milk:
            return Nutrients(kcal: 64, carbs: 4.8, sugar: 4.8, fat: 3.5, saturatedFat: 2.3, protein: 3.3, salt: 0.1)
        case .juice:
            return Nutrients(kcal: 45, carbs: 10, sugar: 9, fat: 0, protein: 0.5)
        case .softDrink:
            return Nutrients(kcal: 42, carbs: 10.6, sugar: 10.6, fat: 0, protein: 0)
        case .beer:
            return Nutrients(kcal: 15, carbs: 3.1, sugar: 0, fat: 0, protein: 0.5)
        case .wine:
            return Nutrients(kcal: 3, carbs: 0.6, sugar: 0.6, fat: 0, protein: 0.1)
        case .spirits:
            return Nutrients(kcal: 0, carbs: 0, fat: 0, protein: 0)
        case .custom:
            return Nutrients()
        }
    }
}

enum DrinkMath {
    /// Dichte von Ethanol in g/ml.
    static let ethanolDensity = 0.789

    /// Alkohol in Gramm aus Menge und Vol-%.
    static func alcoholGrams(volumeMl: Double, abvPercent: Double) -> Double {
        max(0, volumeMl) * max(0, abvPercent) / 100 * ethanolDensity
    }

    /// Nährwerte eines Getränks: Richtwerte pro 100 ml auf die Menge gerechnet,
    /// dazu Alkohol und dessen Energie aus Vol-%.
    static func totals(per100ml: Nutrients, volumeMl: Double, abvPercent: Double) -> Nutrients {
        var total = per100ml.forAmount(volumeMl)
        let alcohol = alcoholGrams(volumeMl: volumeMl, abvPercent: abvPercent)
        if alcohol > 0 {
            total.alcohol = (total.alcohol ?? 0) + alcohol
            total.kcal = (total.kcal ?? 0) + alcohol * Nutrients.EnergyFactor.alcohol
        }
        return total
    }
}
