import Foundation

/// Tagesgrenzen und die Zuordnung von Nächten zu Tagen (SPEC 11.1).
enum DayMath {

    /// Die Nacht, die am Morgen von Tag D endet, gehört zu D.
    static func nightDay(forWake wake: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: wake)
    }

    /// Der Vortag einer Nacht.
    static func previousDay(of day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    static func nextDay(of day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    /// Minuten zwischen dem Tagesbeginn von `day` und `date`.
    ///
    /// Kann über 1440 liegen: Ein Glas Wein um 00:30 nach dem Vortag zählt als
    /// Minute 1470 – also „sehr spät“ und nicht „früh am Morgen“.
    static func minutes(of date: Date, sinceStartOf day: Date, calendar: Calendar = .current) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: day)) / 60
    }

    /// Minuten seit dem Mittag vor dem Datum. Macht Einschlafzeiten vergleichbar:
    /// 23:00 → 660, 01:00 → 780. Ohne diese Verschiebung wäre 01:00 „früher“ als 23:00.
    static func minutesSinceNoon(_ date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        let shifted = minutes - 12 * 60
        return shifted < 0 ? shifted + 24 * 60 : shifted
    }

    /// Median einer Zahlenreihe, `nil` wenn leer.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Alle Tagesanfänge von `start` bis und mit `end`.
    static func days(from start: Date, through end: Date, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
