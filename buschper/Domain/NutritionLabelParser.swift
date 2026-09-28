import CoreGraphics
import Foundation

/// Liest eine fotografierte Nährwerttabelle aus (Texterkennung auf dem Gerät).
///
/// Schweizer Packungen sind oft drei- oder viersprachig („Fett / Matières grasses /
/// Grassi“). Übernommen wird pro Zeile die **erste** Zahl – das ist fast immer die
/// Spalte „pro 100 g/ml“. Die Werte sind ein Vorschlag, den du kontrollierst.
enum NutritionLabelParser {

    /// Ein erkannter Textschnipsel mit Lage im Bild (0…1, Ursprung unten links,
    /// wie bei Vision).
    struct TextLine: Equatable {
        var text: String
        var box: CGRect
    }

    struct Result: Equatable {
        var per100 = Nutrients()
        /// Erkannte Felder in Tabellenreihenfolge.
        var fields: [Nutrients.Field] = []
        /// `true`, wenn die Tabelle „pro 100 ml“ sagt.
        var isLiquid = false

        var isEmpty: Bool { fields.isEmpty }
    }

    // MARK: - Zeilen bilden

    /// Schnipsel, die auf gleicher Höhe liegen, zu Tabellenzeilen zusammenfügen –
    /// von oben nach unten, innerhalb der Zeile von links nach rechts.
    static func rows(from lines: [TextLine]) -> [String] {
        var rows: [(midY: Double, height: Double, items: [TextLine])] = []
        for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
            let midY = Double(line.box.midY)
            let height = Double(line.box.height)
            if let index = rows.firstIndex(where: { abs($0.midY - midY) < 0.5 * min($0.height, height) }) {
                rows[index].items.append(line)
            } else {
                rows.append((midY, height, [line]))
            }
        }
        return rows.map { row in
            row.items.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
    }

    // MARK: - Auswerten

    static func parse(lines: [TextLine]) -> Result {
        parse(rows: rows(from: lines))
    }

    static func parse(rows: [String]) -> Result {
        var result = Result()
        let normalized = rows.map(normalize)

        result.isLiquid = normalized.contains { $0.contains("100 ml") || $0.contains("100ml") }

        if let kcal = energy(in: normalized) {
            result.per100.kcal = kcal
            result.fields.append(.kcal)
        }

        for row in normalized {
            guard let field = field(for: row), result.per100[field] == nil,
                  let value = firstAmount(in: row)
            else { continue }
            result.per100[field] = value
            result.fields.append(field)
        }
        return result
    }

    // MARK: - Schlüsselwörter

    /// Zeilen, die ein Schlüsselwort enthalten, aber etwas anderes meinen.
    private static let ignored = [
        "ungesattigt", "unsaturated", "insature", "insaturi", "mono", "poly",
        "natrium", "sodium", "sodio", "starke", "amidon", "amido", "starch",
    ]

    /// Reihenfolge zählt: „davon gesättigte Fettsäuren“ vor „Fett“, „davon Zucker“
    /// vor „Kohlenhydrate“.
    private static let keywords: [(Nutrients.Field, [String])] = [
        (.saturatedFat, ["gesattigt", "saturated", "satures", "saturi"]),
        (.sugar, ["zucker", "sucres", "zuccheri", "sugars", "sugar"]),
        (.fiber, ["ballaststoff", "fibres", "fibre", "fibra", "fiber"]),
        (.salt, ["salz", "salt", " sel ", " sale "]),
        (.protein, ["eiweiss", "eiweiß", "protein", "proteine", "proteines"]),
        (.carbs, ["kohlenhydrat", "glucides", "carboidrati", "carbohydrate"]),
        (.fat, ["fett", "matieres grasses", "lipides", "grassi", " fat "]),
    ]

    private static let energyWords = ["energie", "energy", "energia", "brennwert", "energetique", "kcal", "kj"]

    private static func field(for row: String) -> Nutrients.Field? {
        let padded = " \(row) "
        guard !ignored.contains(where: { padded.contains($0) }) else { return nil }
        guard !energyWords.contains(where: { padded.contains($0) }) else { return nil }
        return keywords.first { entry in entry.1.contains { padded.contains($0) } }?.0
    }

    // MARK: - Zahlen

    /// Kleinbuchstaben, ohne Akzente, Tausender-Apostroph entfernt, Satzzeichen
    /// als Leerzeichen – damit „Fett/Matières grasses“ zu „fett matieres grasses“ wird.
    static func normalize(_ text: String) -> String {
        var folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_CH"))
            .lowercased()
        folded = folded.replacingOccurrences(of: #"(?<=\d)['’](?=\d{3})"#, with: "", options: .regularExpression)
        folded = folded.replacingOccurrences(of: #"[/|:;()\[\]*]"#, with: " ", options: .regularExpression)
        folded = folded.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return folded.trimmingCharacters(in: .whitespaces)
    }

    private static let number = #"(\d+(?:[.,]\d+)?)"#

    private static func numbers(in text: String, pattern: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[r].replacingOccurrences(of: ",", with: "."))
        }
    }

    /// Erste Menge einer Zeile: bevorzugt mit Einheit („12,5 g“, „<0,5 g“, „80 mg“),
    /// sonst die erste Zahl. Prozentangaben (Tagesbedarf) zählen nie.
    static func firstAmount(in row: String) -> Double? {
        let withoutPercent = row.replacingOccurrences(of: #"\d+(?:[.,]\d+)?\s*%"#, with: " ", options: .regularExpression)
        if let regex = try? NSRegularExpression(pattern: number + #"\s*(mg|g)\b"#),
           let match = regex.firstMatch(in: withoutPercent, range: NSRange(withoutPercent.startIndex..., in: withoutPercent)),
           let valueRange = Range(match.range(at: 1), in: withoutPercent),
           let unitRange = Range(match.range(at: 2), in: withoutPercent),
           let value = Double(withoutPercent[valueRange].replacingOccurrences(of: ",", with: ".")) {
            return withoutPercent[unitRange] == "mg" ? value / 1000 : value
        }
        return numbers(in: withoutPercent, pattern: number).first
    }

    /// Energie in kcal pro 100 g/ml.
    ///
    /// 1. eine Zahl direkt mit „kcal“, 2. ein Zahlenpaar kJ/kcal (a ≈ 4.184 × b),
    /// 3. eine Zahl mit „kJ“, umgerechnet. Gesucht wird in der Energie-Zeile und der
    /// Zeile danach, weil kcal oft darunter steht.
    static func energy(in rows: [String]) -> Double? {
        guard let start = rows.firstIndex(where: { row in
            ["energie", "energy", "energia", "brennwert", "energetique"].contains { row.contains($0) }
                || row.range(of: number + #"\s*(kcal|kj)\b"#, options: .regularExpression) != nil
        }) else { return nil }
        let text = rows[start..<min(rows.count, start + 2)].joined(separator: " ")

        if let kcal = numbers(in: text, pattern: number + #"\s*kcal\b"#).first, kcal <= 950 {
            return kcal
        }
        let all = numbers(in: text, pattern: number)
        for (index, kilojoule) in all.enumerated() {
            for kcal in all[(index + 1)...] where kcal > 0 && abs(kilojoule / 4.184 - kcal) <= max(2, kcal * 0.03) {
                return kcal
            }
        }
        if let kilojoule = numbers(in: text, pattern: number + #"\s*kj\b"#).first {
            return (kilojoule / 4.184).rounded()
        }
        return nil
    }
}
