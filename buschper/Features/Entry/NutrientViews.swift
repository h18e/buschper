import SwiftUI

/// Kompakte Zeile: „640 kcal · 90 g KH · 25 g Eiwiss · 20 g Fett“.
struct NutrientLine: View {
    let nutrients: Nutrients
    var incomplete: Set<Nutrients.Field> = []

    var body: some View {
        Text(Self.text(nutrients, incomplete: incomplete))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
    }

    static func text(_ nutrients: Nutrients, incomplete: Set<Nutrients.Field> = []) -> String {
        var parts = ["\(NumberText.kcal(nutrients.kcal ?? 0)) kcal"]
        func add(_ field: Nutrients.Field, _ label: String) {
            guard let value = nutrients[field] else { return }
            let prefix = incomplete.contains(field) ? "≥" : ""
            parts.append("\(prefix)\(NumberText.kcal(value)) g \(label)")
        }
        add(.carbs, "KH")
        add(.protein, "Eiwiss")
        add(.fat, "Fett")
        return parts.joined(separator: " · ")
    }
}

/// Tabelle aller zehn Nährwerte.
struct NutrientTable: View {
    let nutrients: Nutrients

    var body: some View {
        VStack(spacing: 6) {
            row("Energie", nutrients.kcal, "kcal", digits: 0)
            row("Kohlehydrat", nutrients.carbs, "g")
            row("  dervo Zucker", nutrients.sugar, "g")
            row("Fett", nutrients.fat, "g")
            row("  dervo gsättigti", nutrients.saturatedFat, "g")
            row("Eiwiss", nutrients.protein, "g")
            row("Ballaststoffe", nutrients.fiber, "g")
            row("Salz", nutrients.salt, "g", digits: 2)
            if nutrients.alcohol != nil {
                row("Alkohol", nutrients.alcohol, "g")
            }
            if nutrients.caffeine != nil {
                row("Koffein", nutrients.caffeine, "mg", digits: 0)
            }
        }
        .font(.subheadline)
    }

    private func row(_ label: String, _ value: Double?, _ unit: String, digits: Int = 1) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value.map { "\(Self.format($0, digits: digits)) \(unit)" } ?? "–")
                .monospacedDigit()
                .foregroundStyle(value == nil ? Theme.textTertiary : Theme.textPrimary)
        }
    }

    static func format(_ value: Double, digits: Int) -> String {
        digits == 0 ? NumberText.kcal(value) : String(format: "%.\(digits)f", value)
    }
}

/// Die zehn Nährwerte als Eingabefelder, pro 100 g/ml.
struct NutrientInputs: View {
    @Binding var nutrients: Nutrients
    var isLiquid: Bool

    var body: some View {
        OptionalNumberField(title: "Energie *", value: $nutrients.kcal, unit: "kcal", fractionDigits: 0)
        OptionalNumberField(title: "Kohlehydrat", value: $nutrients.carbs, unit: "g")
        OptionalNumberField(title: "dervo Zucker", value: $nutrients.sugar, unit: "g")
        OptionalNumberField(title: "Fett", value: $nutrients.fat, unit: "g")
        OptionalNumberField(title: "dervo gsättigti", value: $nutrients.saturatedFat, unit: "g")
        OptionalNumberField(title: "Eiwiss", value: $nutrients.protein, unit: "g")
        OptionalNumberField(title: "Ballaststoffe", value: $nutrients.fiber, unit: "g")
        OptionalNumberField(title: "Salz", value: $nutrients.salt, unit: "g", fractionDigits: 2)
        OptionalNumberField(title: "Alkohol", value: $nutrients.alcohol, unit: "g")
        OptionalNumberField(title: "Koffein", value: $nutrients.caffeine, unit: "mg", fractionDigits: 0)
    }
}

/// Zeile eines Suchtreffers.
struct CandidateRow: View {
    let candidate: FoodCandidate
    var onToggleFavorite: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let brand = candidate.brand {
                        Text(brand).lineLimit(1)
                        Text("·")
                    }
                    Text(candidate.sourceLabel).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(NumberText.kcal(candidate.per100.kcal ?? 0)) kcal")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.nutrition)
                Text(candidate.isRecipe ? "pro Portion" : (candidate.isLiquid ? "pro 100 ml" : "pro 100 g"))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: candidate.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(candidate.isFavorite ? Theme.warning : Theme.textTertiary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(candidate.isFavorite ? "Favorit entferne" : "Als Favorit")
            }
        }
        .contentShape(Rectangle())
    }
}
