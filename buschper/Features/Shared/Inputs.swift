import SwiftUI

/// Zahlenfeld für Gramm, kcal, cm … mit Einheit rechts.
///
/// Leeres Feld heisst `nil` – wichtig bei Nährwerten, wo „unbekannt“ etwas anderes
/// ist als 0.
struct OptionalNumberField: View {
    let title: String
    @Binding var value: Double?
    var unit: String = ""
    var fractionDigits = 1

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 12)
            TextField("–", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focused)
                .frame(maxWidth: 110)
                .onChange(of: text) { _, newText in
                    value = Self.parse(newText)
                }
            if !unit.isEmpty {
                Text(unit)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
        .onAppear { text = Self.format(value, digits: fractionDigits) }
        .onChange(of: value) { _, newValue in
            // Nur von aussen gesetzte Werte übernehmen, nicht während des Tippens.
            if !focused {
                text = Self.format(newValue, digits: fractionDigits)
            }
        }
    }

    /// Akzeptiert Punkt und Komma als Dezimaltrennzeichen.
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    static func format(_ value: Double?, digits: Int) -> String {
        guard let value else { return "" }
        if abs(value - value.rounded()) < 0.0001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.\(digits)f", value)
    }
}

/// Zahlenfeld für Werte, die nie leer sein dürfen.
struct NumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""
    var fractionDigits = 1

    var body: some View {
        OptionalNumberField(
            title: title,
            value: Binding(
                get: { value },
                set: { if let newValue = $0 { value = newValue } }
            ),
            unit: unit,
            fractionDigits: fractionDigits
        )
    }
}
