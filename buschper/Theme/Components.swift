import SwiftUI

/// Kleine farbige Markierung, z. B. „Schätzig“ oder ein Schlaf-Faktor.
struct BadgeView: View {
    let text: String
    var color: Color = Theme.accent
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.16), in: Capsule())
        .foregroundStyle(color)
    }
}

/// Kopf einer Dashboard-Karte: Titel links, Symbol im farbigen Kreis rechts.
struct CardHeader: View {
    let title: String
    var subtitle: String?
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.background)
                .frame(width: 36, height: 36)
                .background(color, in: Circle())
                .accessibilityHidden(true)
        }
    }
}

/// Grosse Zahl mit kleiner Beschriftung darunter, wie „68.8 / Kilogramm“.
struct StatValue: View {
    let value: String
    let caption: String
    var alignment: HorizontalAlignment = .leading
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Ist/Ziel-Kachel, wie „Carbs 173 / 209“.
struct TargetTile: View {
    let title: String
    let value: Double
    let target: Double?
    var unit: String = ""
    let color: Color
    /// `true`, wenn nicht alle Einträge den Wert kennen – dann steht ein „≥“ davor.
    var incomplete = false

    private var fraction: Double {
        guard let target, target > 0 else { return 0 }
        return value / target
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text((incomplete ? "≥" : "") + NumberText.kcal(value))
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                if let target {
                    Text("/\(NumberText.kcal(target))\(unit)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            ProgressBar(fraction: fraction, color: color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Dünner Fortschrittsbalken. Über 100 % wird er zur Warnung eingefärbt.
struct ProgressBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(fraction > 1.05 ? Theme.warning : color)
                    .frame(width: max(height, geometry.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Leerer Zustand mit Symbol, Text und optionaler Aktion.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

/// Zeile mit Beschriftung links und Wert rechts.
struct LabeledValueRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 12)
            value
        }
    }
}

/// Hinweis, der überall gleich aussieht, wo buschper über Schlaf urteilt.
struct MedicalDisclaimer: View {
    var body: some View {
        Label("Kei medizinischi Beratig.", systemImage: "info.circle")
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
    }
}
