import Foundation

struct WeightSample: Equatable {
    var date: Date
    var kg: Double
}

struct DailyWeight: Equatable, Identifiable {
    var day: Date
    var kg: Double
    var id: Date { day }
}

/// Gewichtsverlauf (SPEC 9).
enum WeightMath {

    /// Ein Wert pro Tag. Bei mehreren Messungen gilt der tiefste, weil das meist
    /// die Messung am Morgen ist.
    static func daily(_ samples: [WeightSample], calendar: Calendar = .current) -> [DailyWeight] {
        var byDay: [Date: Double] = [:]
        for sample in samples where sample.kg > 0 {
            let day = calendar.startOfDay(for: sample.date)
            byDay[day] = min(byDay[day] ?? .infinity, sample.kg)
        }
        return byDay
            .map { DailyWeight(day: $0.key, kg: $0.value) }
            .sorted { $0.day < $1.day }
    }

    /// Durchschnitt der Tageswerte in den `days` Tagen bis und mit `endingAt`.
    /// Grundlage für den Kalorienbedarf (Q12).
    static func average(_ daily: [DailyWeight], days: Int = 7, endingAt end: Date, calendar: Calendar = .current) -> Double? {
        let last = calendar.startOfDay(for: end)
        guard let first = calendar.date(byAdding: .day, value: -(days - 1), to: last) else { return nil }
        let window = daily.filter { $0.day >= first && $0.day <= last }
        return DayMath.average(window.map(\.kg))
    }

    /// Gleitender Durchschnitt für die Linie im Graphen.
    static func movingAverage(_ daily: [DailyWeight], days: Int = 7, calendar: Calendar = .current) -> [DailyWeight] {
        daily.compactMap { point in
            average(daily, days: days, endingAt: point.day, calendar: calendar).map {
                DailyWeight(day: point.day, kg: $0)
            }
        }
    }

    /// Letzter bekannter Wert, falls die letzte Woche leer ist.
    static func latest(_ daily: [DailyWeight]) -> DailyWeight? {
        daily.max { $0.day < $1.day }
    }

    /// Veränderung vom ersten zum letzten Wert im Zeitraum.
    static func change(_ daily: [DailyWeight]) -> Double? {
        let sorted = daily.sorted { $0.day < $1.day }
        guard let first = sorted.first, let last = sorted.last, sorted.count > 1 else { return nil }
        return last.kg - first.kg
    }
}
