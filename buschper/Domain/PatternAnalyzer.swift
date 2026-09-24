import Foundation

/// Eine gespeicherte Nacht, reduziert auf das, was die Musterauswertung braucht.
struct NightSample: Equatable {
    var score: Double
    var isBad: Bool
    var factors: Set<SleepFactor>
    var excluded: Bool
}

/// Vergleich der Nächte mit und ohne einen Faktor am Vortag (SPEC 12.4).
struct FactorPattern: Equatable, Identifiable {
    var factor: SleepFactor
    var nightsWith: Int
    var nightsWithout: Int
    var averageWith: Double?
    var averageWithout: Double?
    var badWith: Int
    var badWithout: Int

    var id: SleepFactor { factor }

    /// Wie viele Punkte tiefer der Score im Schnitt nach diesem Faktor liegt.
    /// Positiv heisst: der Faktor geht mit schlechterem Schlaf einher.
    var scoreDrop: Double? {
        guard let averageWith, let averageWithout else { return nil }
        return averageWithout - averageWith
    }

    var badShareWith: Double? {
        nightsWith > 0 ? Double(badWith) / Double(nightsWith) : nil
    }

    var badShareWithout: Double? {
        nightsWithout > 0 ? Double(badWithout) / Double(nightsWithout) : nil
    }

    /// Erst ab je 5 Nächten in beiden Gruppen wird ein Muster gezeigt.
    var isReliable: Bool {
        nightsWith >= PatternAnalyzer.minimumNights && nightsWithout >= PatternAnalyzer.minimumNights
    }
}

enum PatternAnalyzer {
    static let minimumNights = 5

    /// Ein Eintrag pro Faktor. Verlässliche Muster zuerst, stärkster Effekt oben;
    /// danach die, für die noch Daten fehlen.
    static func patterns(from samples: [NightSample]) -> [FactorPattern] {
        let included = samples.filter { !$0.excluded }

        let patterns = SleepFactor.allCases.map { factor -> FactorPattern in
            let with = included.filter { $0.factors.contains(factor) }
            let without = included.filter { !$0.factors.contains(factor) }
            return FactorPattern(
                factor: factor,
                nightsWith: with.count,
                nightsWithout: without.count,
                averageWith: DayMath.average(with.map(\.score)),
                averageWithout: DayMath.average(without.map(\.score)),
                badWith: with.filter(\.isBad).count,
                badWithout: without.filter(\.isBad).count
            )
        }

        return patterns.sorted { lhs, rhs in
            if lhs.isReliable != rhs.isReliable {
                return lhs.isReliable
            }
            if lhs.isReliable {
                return (lhs.scoreDrop ?? 0) > (rhs.scoreDrop ?? 0)
            }
            // Noch nicht verlässlich: die, die am nächsten dran sind, zuerst.
            return min(lhs.nightsWith, lhs.nightsWithout) > min(rhs.nightsWith, rhs.nightsWithout)
        }
    }
}
