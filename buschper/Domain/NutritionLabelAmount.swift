import Foundation

/// Für welche Menge die Werte einer fotografierten Nährwerttabelle gelten.
/// Wird nach jedem Import von Hand gewählt (SPEC 5.5).
enum LabelBasis: String, CaseIterable, Identifiable {
    case per100
    case piece
    case portion
    case wholeMeal

    var id: String { rawValue }

    func label(isLiquid: Bool) -> String {
        switch self {
        case .per100: return isLiquid ? "100 ml" : "100 g"
        case .piece: return "1 Stück"
        case .portion: return "1 Portion"
        case .wholeMeal: return "Ganzi Mahlzyt"
        }
    }

    /// Name der Portionsgrösse, die beim Produkt entsteht.
    var portionName: String {
        switch self {
        case .piece: return "Stück"
        case .per100, .portion, .wholeMeal: return "Portion"
        }
    }
}

/// Erkannte Tabelle samt der gewählten Menge.
struct LabelImport: Equatable {
    /// Werte so, wie sie auf der Tabelle stehen.
    var values: Nutrients
    /// Erkannte Felder – nur diese werden übernommen.
    var fields: [Nutrients.Field]
    var isLiquid: Bool
    var basis: LabelBasis
    /// Produkt: Gewicht von 1 Stück/Portion (bei 100 g fakultativ die
    /// Portionsgrösse). Mahlzeit: bei 100 g die gegessene Menge.
    var grams: Double?
    /// Mahlzeit: Anzahl Stück/Portionen.
    var count: Double = 1

    private var hasGrams: Bool { (grams ?? 0) > 0 }

    /// Werte pro 100 g/ml für ein Produkt. Stück und Portion brauchen ihr Gewicht.
    var per100: Nutrients? {
        switch basis {
        case .per100: return values
        case .piece, .portion:
            guard let grams, grams > 0 else { return nil }
            return values.scaled(by: 100 / grams)
        case .wholeMeal: return nil
        }
    }

    /// Werte für das, was gegessen wird („Ganzi Mahlzyt“).
    var total: Nutrients? {
        switch basis {
        case .per100:
            guard let grams, grams > 0 else { return nil }
            return values.forAmount(grams)
        case .piece, .portion:
            guard count > 0 else { return nil }
            return values.scaled(by: count)
        case .wholeMeal: return values
        }
    }

    /// Portionsgrösse, die das Produkt bekommt – z. B. „Portion = 80 g“.
    var portion: ProductDraft.PortionDraft? {
        guard basis != .wholeMeal, let grams, grams > 0 else { return nil }
        return ProductDraft.PortionDraft(name: basis.portionName, grams: grams)
    }

    /// Erkannte Werte ins Produktformular schreiben. `false`, wenn die
    /// Angaben nicht reichen (z. B. Stück ohne Gewicht).
    @discardableResult
    func apply(to draft: inout ProductDraft) -> Bool {
        guard let per100 else { return false }
        for field in fields {
            draft.per100[field] = per100[field].map { ($0 * 10).rounded() / 10 }
        }
        if isLiquid { draft.isLiquid = true }
        if let portion, !draft.portions.contains(where: { $0.grams == portion.grams }) {
            draft.portions.append(portion)
        }
        return true
    }
}
