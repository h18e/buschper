import Foundation

/// Karten des Dashboards (SPEC 13.1).
enum DashboardCard: String, Codable, CaseIterable, Identifiable {
    case energy
    case dayLog
    case fluid
    case activity
    case weight
    case sleep
    case weekAverage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .energy: return "Kalorie & Makros"
        case .dayLog: return "Tagesliste"
        case .fluid: return "Flüssigkeit"
        case .activity: return "Aktivität"
        case .weight: return "Gwicht"
        case .sleep: return "Schlaf"
        case .weekAverage: return "Wuchenschnitt"
        }
    }

    var symbolName: String {
        switch self {
        case .energy: return "flame.fill"
        case .dayLog: return "list.bullet.rectangle.fill"
        case .fluid: return "drop.fill"
        case .activity: return "figure.walk"
        case .weight: return "scalemass.fill"
        case .sleep: return "moon.zzz.fill"
        case .weekAverage: return "calendar"
        }
    }
}

/// Reihenfolge und Sichtbarkeit der Karten. Wird im Profil gespeichert und
/// gleicht damit über iCloud ab.
struct DashboardLayout: Codable, Equatable {
    var order: [DashboardCard]
    var hidden: Set<DashboardCard>

    static let standard = DashboardLayout(order: DashboardCard.allCases, hidden: [])

    /// Sichtbare Karten in der gewählten Reihenfolge.
    var visibleCards: [DashboardCard] {
        normalized.order.filter { !hidden.contains($0) }
    }

    /// Karten, die eine neuere App-Version dazubringt, hinten anhängen, damit sie
    /// nicht unsichtbar bleiben. Doppelte oder unbekannte fallen weg.
    var normalized: DashboardLayout {
        var seen = Set<DashboardCard>()
        var result: [DashboardCard] = []
        for card in order where !seen.contains(card) {
            seen.insert(card)
            result.append(card)
        }
        for card in DashboardCard.allCases where !seen.contains(card) {
            result.append(card)
        }
        return DashboardLayout(order: result, hidden: hidden)
    }

    func isVisible(_ card: DashboardCard) -> Bool {
        !hidden.contains(card)
    }

    mutating func setVisible(_ card: DashboardCard, _ visible: Bool) {
        if visible {
            hidden.remove(card)
        } else {
            hidden.insert(card)
        }
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var cards = normalized.order
        let moving = source.sorted().map { cards[$0] }
        for index in source.sorted(by: >) {
            cards.remove(at: index)
        }
        let removedBefore = source.filter { $0 < destination }.count
        let insertAt = min(max(0, destination - removedBefore), cards.count)
        cards.insert(contentsOf: moving, at: insertAt)
        order = cards
    }

    // MARK: - Speichern

    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ json: String?) -> DashboardLayout {
        guard let json, let data = json.data(using: .utf8),
              let layout = try? JSONDecoder().decode(DashboardLayout.self, from: data)
        else { return .standard }
        return layout.normalized
    }
}

/// Zeitraum der Graphen (Q34).
enum ChartRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    var label: String {
        switch self {
        case .week: return "Wuche"
        case .month: return "Monet"
        case .quarter: return "3 Mönet"
        }
    }
}
