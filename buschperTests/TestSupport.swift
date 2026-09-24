import Foundation

/// Feste Zeitzone für alle Tests, damit Ergebnisse nicht vom Gerät abhängen.
enum TestCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

extension Double {
    /// Vergleich mit Toleranz für Gleitkommazahlen.
    func isClose(to other: Double, tolerance: Double = 0.01) -> Bool {
        abs(self - other) <= tolerance
    }
}
