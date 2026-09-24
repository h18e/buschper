import SwiftUI

/// Farben und Flächen von buschper (SPEC 3).
///
/// Nur dunkel. Flächen wie in Frostify und Räpplispauter – tiefer, fast schwarzer
/// Hintergrund, leicht aufgehellte Karten –, dazu **eine feste Farbe pro Bereich**.
/// Die Bereichsfarbe gilt überall gleich: Karte, Graph, Erfassungsdialog.
enum Theme {

    // MARK: - Flächen

    static let background = Color(red: 0.047, green: 0.051, blue: 0.063)
    static let surface = Color(red: 0.090, green: 0.098, blue: 0.118)
    static let surfaceElevated = Color(red: 0.129, green: 0.137, blue: 0.161)
    static let separator = Color.white.opacity(0.08)
    static let track = Color.white.opacity(0.08)

    // MARK: - Text

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    // MARK: - Marke

    /// Akzentfarbe für Knöpfe und Auswahl. Bewusst keine der Bereichsfarben,
    /// damit ein pinker Knopf nie mit „Ernährung“ oder „Schlaf“ verwechselt wird.
    static let accent = Color(red: 0.980, green: 0.529, blue: 0.690)

    // MARK: - Bereiche

    static let nutrition = Color(red: 0.400, green: 0.839, blue: 0.529)
    static let fluid = Color(red: 0.365, green: 0.667, blue: 0.988)
    static let activity = Color(red: 0.980, green: 0.420, blue: 0.408)
    static let weight = Color(red: 0.992, green: 0.737, blue: 0.325)
    static let sleep = Color(red: 0.690, green: 0.569, blue: 0.992)

    /// Makros innerhalb der Ernährung: Abstufungen, damit die Karte ruhig bleibt.
    static let carbs = Color(red: 0.992, green: 0.831, blue: 0.451)
    static let protein = Color(red: 0.557, green: 0.878, blue: 0.890)
    static let fat = Color(red: 0.980, green: 0.620, blue: 0.451)
    static let fiber = Color(red: 0.667, green: 0.851, blue: 0.431)

    // MARK: - Zustände

    static let good = Color(red: 0.400, green: 0.839, blue: 0.529)
    static let warning = Color(red: 0.992, green: 0.737, blue: 0.325)
    static let bad = Color(red: 0.980, green: 0.420, blue: 0.408)

    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
}

extension DashboardCard {
    var color: Color {
        switch self {
        case .energy, .dayLog, .weekAverage: return Theme.nutrition
        case .fluid: return Theme.fluid
        case .activity: return Theme.activity
        case .weight: return Theme.weight
        case .sleep: return Theme.sleep
        }
    }
}

// MARK: - Bausteine für den Seitenaufbau

/// Karte im App-Stil. Mit `tint` bekommt sie einen Hauch der Bereichsfarbe,
/// wie die farbigen Karten im Vorbild-Screenshot – aber gedämpft für den dunklen Grund.
struct CardBackground: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [(tint ?? .clear).opacity(0.16), (tint ?? .clear).opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke((tint ?? .white).opacity(tint == nil ? 0.08 : 0.22), lineWidth: 1)
            )
    }
}

extension View {
    func card(tint: Color? = nil, padding: CGFloat = 16) -> some View {
        modifier(CardBackground(tint: tint, padding: padding))
    }

    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// Listen und Formulare auf den dunklen Hintergrund stellen.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .screenBackground()
    }
}
