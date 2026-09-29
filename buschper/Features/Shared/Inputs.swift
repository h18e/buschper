import CoreData
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
    /// Das Zahlen-Tastenfeld hat kein Minus – dafür gibt es einen ±-Knopf.
    var allowsNegative = false

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 12)
            if allowsNegative {
                Button {
                    value = -(value ?? 0)
                } label: {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 32, height: 28)
                        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Vorzeiche wächsle")
            }
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
            // Von aussen gesetzte Werte (Schieber, Schnelltasten) immer übernehmen.
            // Nur wenn der Wert ohnehin dem Getippten entspricht, bleibt der Text –
            // sonst würde z. B. „1.“ während des Tippens zu „1“ umgeschrieben.
            if Self.parse(text) != newValue {
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
            .replacingOccurrences(of: "−", with: "-")
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
    var allowsNegative = false

    var body: some View {
        OptionalNumberField(
            title: title,
            value: Binding(
                get: { value },
                set: { if let newValue = $0 { value = newValue } }
            ),
            unit: unit,
            fractionDigits: fractionDigits,
            allowsNegative: allowsNegative
        )
    }
}

/// Mengeneingabe mit grosser Zahl, Schieber, −/+ und Schnelltasten.
///
/// Alle Wege ändern denselben Wert: tippen, schieben, antippen. Reicht der
/// Schieber nicht (z. B. 1.5 kg), einfach die Zahl oben eintippen – der Schieber
/// wächst mit.
struct AmountInput: View {
    @Binding var value: Double
    let unit: String
    /// Obergrenze des Schiebers; grössere Werte lassen sich eintippen.
    let sliderMax: Double
    let step: Double
    var quickValues: [Double] = []
    var tint: Color = Theme.accent

    @State private var text = ""
    @FocusState private var focused: Bool

    private var upperBound: Double { max(sliderMax, value) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                roundButton("minus") { value = max(0, ((value - step) / step).rounded() * step) }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0", text: $text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .focused($focused)
                        .fixedSize()
                        .onChange(of: text) { _, newText in
                            if let parsed = OptionalNumberField.parse(newText) {
                                value = max(0, parsed)
                            }
                        }
                    Text(unit)
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
                roundButton("plus") { value = ((value + step) / step).rounded() * step }
            }

            Slider(value: Binding(
                get: { min(value, upperBound) },
                set: { newValue in
                    focused = false
                    value = (newValue / step).rounded() * step
                }
            ), in: 0...upperBound, step: step)
            .tint(tint)

            if !quickValues.isEmpty {
                HStack(spacing: 6) {
                    ForEach(quickValues, id: \.self) { quick in
                        Button(NumberText.amount(quick)) {
                            focused = false
                            value = quick
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(abs(value - quick) < 0.001 ? tint : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .onAppear { text = OptionalNumberField.format(value, digits: 2) }
        .onChange(of: value) { _, newValue in
            if OptionalNumberField.parse(text) != newValue {
                text = OptionalNumberField.format(newValue, digits: 2)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { focused = false }
            }
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(Theme.surfaceElevated, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }
}

