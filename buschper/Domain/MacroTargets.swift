import Foundation

/// Verteilung der Kalorien auf die Makronährstoffe, in Prozent (SPEC 4.5).
struct MacroSplit: Codable, Equatable {
    var carbsPercent: Double
    var proteinPercent: Double
    var fatPercent: Double

    /// Vorgabe beim ersten Start: KH 45 % · Eiweiss 25 % · Fett 30 %.
    static let standard = MacroSplit(carbsPercent: 45, proteinPercent: 25, fatPercent: 30)

    var sum: Double { carbsPercent + proteinPercent + fatPercent }

    /// Nur eine gültige Verteilung lässt sich sichern: jeder Anteil zwischen 0 und
    /// 100, zusammen genau 100.
    var isValid: Bool {
        let parts = [carbsPercent, proteinPercent, fatPercent]
        return parts.allSatisfy { (0...100).contains($0) } && abs(sum - 100) < 0.01
    }
}

/// Tagesziele in Gramm.
struct MacroTargets: Equatable {
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    /// Mindestziel, kein Anteil an den kcal.
    var fiberMinG: Double

    static let defaultFiberMinG = 30.0

    /// Gramm-Ziele aus dem kcal-Budget. Weil das Budget live wächst, wachsen die
    /// Gramm-Ziele im gleichen Verhältnis mit.
    static func from(kcalBudget: Double, split: MacroSplit, fiberMinG: Double) -> MacroTargets {
        let budget = max(0, kcalBudget)
        return MacroTargets(
            carbsG: budget * split.carbsPercent / 100 / Nutrients.EnergyFactor.carbs,
            proteinG: budget * split.proteinPercent / 100 / Nutrients.EnergyFactor.protein,
            fatG: budget * split.fatPercent / 100 / Nutrients.EnergyFactor.fat,
            fiberMinG: fiberMinG
        )
    }
}
