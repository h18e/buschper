import Foundation

/// CSV für Excel (SPEC 16): Semikolon als Trennzeichen, UTF-8 mit BOM, damit
/// Excel Umlaute richtig erkennt. Dezimalpunkt wie in der Schweiz üblich.
enum CSVWriter {
    static let separator = ";"
    static let byteOrderMark = "\u{FEFF}"

    static func make(header: [String], rows: [[String]]) -> String {
        var lines = [header.map(escape).joined(separator: separator)]
        lines += rows.map { $0.map(escape).joined(separator: separator) }
        return byteOrderMark + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Felder mit Trennzeichen, Anführungszeichen oder Zeilenumbruch in
    /// Anführungszeichen setzen; innere Anführungszeichen verdoppeln.
    static func escape(_ field: String) -> String {
        let needsQuotes = field.contains(separator) || field.contains("\"")
            || field.contains("\n") || field.contains("\r")
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Zahl oder leer, wenn unbekannt. Höchstens zwei Nachkommastellen.
    static func number(_ value: Double?) -> String {
        guard let value else { return "" }
        if abs(value - value.rounded()) < 0.0005 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.2f", value)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func timestamp(_ date: Date?) -> String {
        date.map { timestampFormatter.string(from: $0) } ?? ""
    }

    static func day(_ date: Date?) -> String {
        date.map { dayFormatter.string(from: $0) } ?? ""
    }

    /// Kopfzeile und Werte der zehn Nährwerte, in fester Reihenfolge.
    static let nutrientHeader = [
        "kcal", "Kohlenhydrate g", "Zucker g", "Fett g", "gesaettigte Fettsaeuren g",
        "Eiweiss g", "Ballaststoffe g", "Salz g", "Alkohol g", "Koffein mg"
    ]

    static func nutrientFields(_ nutrients: Nutrients) -> [String] {
        Nutrients.Field.allCases.map { number(nutrients[$0]) }
    }
}
