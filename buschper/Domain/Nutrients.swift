import Foundation

/// Die zehn Nährwerte, die buschper führt (SPEC 5.1).
///
/// Gleiche Struktur für zwei Bedeutungen: **pro 100 g/ml** bei Produkten und
/// Rezeptzutaten, **absolut** bei geloggten Einträgen. Welche gemeint ist, sagt
/// jeweils der Name der Eigenschaft (`per100`, `total`).
///
/// `nil` heisst „nicht bekannt“, `0` heisst „enthält nichts“. Diese Unterscheidung
/// ist der Grund, warum die Werte optional sind: Ein Produkt ohne Angabe zu
/// Ballaststoffen soll die Tagessumme nicht stillschweigend als vollständig
/// erscheinen lassen.
struct Nutrients: Codable, Equatable, Hashable {
    var kcal: Double?
    var carbs: Double?
    var sugar: Double?
    var fat: Double?
    var saturatedFat: Double?
    var protein: Double?
    var fiber: Double?
    var salt: Double?
    var alcohol: Double?
    /// Milligramm, alle anderen Werte in Gramm.
    var caffeine: Double?

    static let empty = Nutrients()

    enum Field: String, CaseIterable, Codable, Hashable {
        case kcal, carbs, sugar, fat, saturatedFat, protein, fiber, salt, alcohol, caffeine
    }

    subscript(field: Field) -> Double? {
        get {
            switch field {
            case .kcal: return kcal
            case .carbs: return carbs
            case .sugar: return sugar
            case .fat: return fat
            case .saturatedFat: return saturatedFat
            case .protein: return protein
            case .fiber: return fiber
            case .salt: return salt
            case .alcohol: return alcohol
            case .caffeine: return caffeine
            }
        }
        set {
            switch field {
            case .kcal: kcal = newValue
            case .carbs: carbs = newValue
            case .sugar: sugar = newValue
            case .fat: fat = newValue
            case .saturatedFat: saturatedFat = newValue
            case .protein: protein = newValue
            case .fiber: fiber = newValue
            case .salt: salt = newValue
            case .alcohol: alcohol = newValue
            case .caffeine: caffeine = newValue
            }
        }
    }

    /// `true`, wenn kein einziger Wert bekannt ist.
    var isEmpty: Bool {
        Field.allCases.allSatisfy { self[$0] == nil }
    }

    /// Jeden bekannten Wert mit `factor` multiplizieren. Unbekanntes bleibt unbekannt.
    func scaled(by factor: Double) -> Nutrients {
        var result = Nutrients()
        for field in Field.allCases {
            result[field] = self[field].map { $0 * factor }
        }
        return result
    }

    /// Aus Werten pro 100 g/ml die Werte für eine Menge berechnen.
    func forAmount(_ amount: Double) -> Nutrients {
        scaled(by: amount / 100)
    }

    /// Summe zweier Wertesätze. Nur wenn **beide** Seiten einen Wert nicht kennen,
    /// bleibt er unbekannt. Ob dabei etwas gefehlt hat, weiss `NutrientSum`.
    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        var result = Nutrients()
        for field in Field.allCases {
            switch (lhs[field], rhs[field]) {
            case (nil, nil): result[field] = nil
            case let (value?, nil), let (nil, value?): result[field] = value
            case let (a?, b?): result[field] = a + b
            }
        }
        return result
    }

    // MARK: - Energie aus Makros

    /// kcal pro Gramm, wie sie auch auf Schweizer Packungen gerechnet werden.
    enum EnergyFactor {
        static let carbs = 4.0
        static let protein = 4.0
        static let fat = 9.0
        static let alcohol = 7.0
    }

    /// Energie eines Gerichts, von dem nur die Makros bekannt sind (Schnell-Iitrag).
    static func kcal(carbs: Double?, protein: Double?, fat: Double?, alcohol: Double? = nil) -> Double {
        (carbs ?? 0) * EnergyFactor.carbs
            + (protein ?? 0) * EnergyFactor.protein
            + (fat ?? 0) * EnergyFactor.fat
            + (alcohol ?? 0) * EnergyFactor.alcohol
    }

    // MARK: - Speichern

    /// Kompakte JSON-Form für Core Data. Unbekannte Werte werden weggelassen.
    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8)
        else { return "{}" }
        return string
    }

    init(jsonString: String?) {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Nutrients.self, from: data)
        else {
            self.init()
            return
        }
        self = decoded
    }

    init(
        kcal: Double? = nil,
        carbs: Double? = nil,
        sugar: Double? = nil,
        fat: Double? = nil,
        saturatedFat: Double? = nil,
        protein: Double? = nil,
        fiber: Double? = nil,
        salt: Double? = nil,
        alcohol: Double? = nil,
        caffeine: Double? = nil
    ) {
        self.kcal = kcal
        self.carbs = carbs
        self.sugar = sugar
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.protein = protein
        self.fiber = fiber
        self.salt = salt
        self.alcohol = alcohol
        self.caffeine = caffeine
    }
}

/// Summe über mehrere Einträge, mit dem Wissen, wo Angaben gefehlt haben.
///
/// Beispiel: Drei Einträge, einer ohne Ballaststoff-Angabe. Die Summe zeigt die
/// Ballaststoffe der anderen zwei, und `incompleteFields` enthält `.fiber` –
/// die Oberfläche setzt dann ein „≥“ oder einen Hinweis davor.
struct NutrientSum: Equatable {
    var values: Nutrients
    var incompleteFields: Set<Nutrients.Field>
    var entryCount: Int

    static let zero = NutrientSum(values: Nutrients(), incompleteFields: [], entryCount: 0)

    init(values: Nutrients, incompleteFields: Set<Nutrients.Field>, entryCount: Int) {
        self.values = values
        self.incompleteFields = incompleteFields
        self.entryCount = entryCount
    }

    init<S: Sequence>(_ items: S) where S.Element == Nutrients {
        var values = Nutrients()
        var known: [Nutrients.Field: Int] = [:]
        var count = 0
        for item in items {
            count += 1
            values = values + item
            for field in Nutrients.Field.allCases where item[field] != nil {
                known[field, default: 0] += 1
            }
        }
        var incomplete = Set<Nutrients.Field>()
        for field in Nutrients.Field.allCases {
            let seen = known[field] ?? 0
            // Ein Wert gilt als unvollständig, wenn ihn manche Einträge kennen und
            // andere nicht. Kennt ihn niemand, ist er schlicht unbekannt (nil).
            if seen > 0 && seen < count {
                incomplete.insert(field)
            }
        }
        self.init(values: values, incompleteFields: incomplete, entryCount: count)
    }

    /// Kalorien als Zahl – unbekannt zählt als 0, weil kcal Pflicht ist.
    var kcal: Double { values.kcal ?? 0 }

    static func + (lhs: NutrientSum, rhs: NutrientSum) -> NutrientSum {
        var incomplete = lhs.incompleteFields.union(rhs.incompleteFields)
        // Kennt nur eine Seite einen Wert und hat die andere Einträge, fehlt er dort.
        for field in Nutrients.Field.allCases {
            let left = lhs.values[field]
            let right = rhs.values[field]
            if (left == nil && lhs.entryCount > 0 && right != nil)
                || (right == nil && rhs.entryCount > 0 && left != nil) {
                incomplete.insert(field)
            }
        }
        return NutrientSum(
            values: lhs.values + rhs.values,
            incompleteFields: incomplete,
            entryCount: lhs.entryCount + rhs.entryCount
        )
    }
}
