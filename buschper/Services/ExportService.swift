import CoreData
import Foundation

/// CSV-Export aller Daten (SPEC 16).
@MainActor
final class ExportService {
    enum Range: String, CaseIterable, Identifiable {
        case all, last90, last30
        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "Aues"
            case .last90: return "90 Täg"
            case .last30: return "30 Täg"
            }
        }

        func start(from now: Date) -> Date {
            switch self {
            case .all: return .distantPast
            case .last90: return Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
            case .last30: return Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            }
        }
    }

    private let store: DataStore
    private let dayData: DayDataService

    init(store: DataStore, dayData: DayDataService) {
        self.store = store
        self.dayData = dayData
    }

    /// Schreibt die Dateien in einen frischen temporären Ordner und gibt ihre Adressen zurück.
    func export(range: Range) async throws -> [URL] {
        let now = Date()
        let start = range.start(from: now)
        let end = DayMath.nextDay(of: now)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("buschper-export-\(Int(now.timeIntervalSince1970))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var files: [URL] = []
        func write(_ name: String, _ content: String) throws {
            let url = folder.appendingPathComponent(name)
            try content.write(to: url, atomically: true, encoding: .utf8)
            files.append(url)
        }

        try write("mahlzeiten.csv", meals(from: start, to: end))
        try write("getraenke.csv", drinks(from: start, to: end))
        try write("trainings.csv", workouts(from: start, to: end))
        try write("gewicht.csv", await weights(from: range == .all ? (Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now) : start, to: end))
        try write("schlaf.csv", nights(from: start, to: end))
        return files
    }

    private func meals(from start: Date, to end: Date) -> String {
        let header = ["Datum", "Zeit", "Kategorie", "Mahlzeit", "Eintrag", "Menge", "Einheit", "Gramm", "Art"] + CSVWriter.nutrientHeader
        var rows: [[String]] = []
        for meal in store.meals(from: start, to: end) {
            for entry in meal.entryList {
                rows.append([
                    CSVWriter.day(meal.timestamp),
                    CSVWriter.timestamp(meal.timestamp).components(separatedBy: " ").last ?? "",
                    meal.category.label,
                    meal.displayTitle,
                    entry.displayName,
                    CSVWriter.number(entry.kind == .recipe ? entry.servings : entry.amount),
                    entry.kind == .recipe ? "Portion" : (entry.unitLabel ?? ""),
                    CSVWriter.number(entry.grams > 0 ? entry.grams : nil),
                    kindLabel(entry.kind)
                ] + CSVWriter.nutrientFields(entry.total))
            }
        }
        return CSVWriter.make(header: header, rows: rows)
    }

    private func kindLabel(_ kind: FoodEntryKind) -> String {
        switch kind {
        case .product: return "Eigets Produkt"
        case .external: return "Datebank"
        case .recipe: return "Rezept"
        case .quick: return "Schnell-Iitrag"
        }
    }

    private func drinks(from start: Date, to end: Date) -> String {
        let header = ["Zeitpunkt", "Typ", "Name", "Menge ml", "Vol-%", "zaehlt zur Fluessigkeit"] + CSVWriter.nutrientHeader
        let rows = store.drinks(from: start, to: end).map { drink in
            [
                CSVWriter.timestamp(drink.timestamp),
                drink.drinkType.label,
                drink.displayName,
                CSVWriter.number(drink.volumeMl),
                CSVWriter.number(drink.abvPercent > 0 ? drink.abvPercent : nil),
                drink.countsAsFluid ? "ja" : "nein"
            ] + CSVWriter.nutrientFields(drink.total)
        }
        return CSVWriter.make(header: header, rows: rows)
    }

    private func workouts(from start: Date, to end: Date) -> String {
        let header = ["Start", "Sportart", "Dauer min", "Intensitaet", "kcal", "kcal von Hand", "Notiz"]
        let rows = store.fetch(
            WorkoutEntry.self,
            predicate: DataStore.rangePredicate("start", from: start, to: end),
            sort: [NSSortDescriptor(key: "start", ascending: true)]
        ).map { workout in
            [
                CSVWriter.timestamp(workout.start),
                workout.sportType.label,
                CSVWriter.number(workout.durationMinutes),
                workout.intensity.label,
                CSVWriter.number(workout.kcal),
                workout.kcalIsManual ? "ja" : "nein",
                workout.note ?? ""
            ]
        }
        return CSVWriter.make(header: header, rows: rows)
    }

    private func weights(from start: Date, to end: Date) async -> String {
        let header = ["Zeitpunkt", "kg", "Quelle"]
        let rows = await dayData.weights(from: start, to: end).map { point -> [String] in
            let source: String
            switch point.origin {
            case .manual: source = "buschper (von Hand)"
            case .health(_, let name): source = name
            }
            return [CSVWriter.timestamp(point.date), CSVWriter.number(point.kg), source]
        }
        return CSVWriter.make(header: header, rows: rows)
    }

    private func nights(from start: Date, to end: Date) -> String {
        let header = ["Nacht", "Score", "schlecht", "Gruende", "Schlaf min", "Tief min", "REM min", "Kern min", "Wach min",
                      "Eingeschlafen", "Aufgewacht", "Sterne", "Faktoren Vortag", "Notiz", "Marken", "ausgeschlossen"]
        let rows = store.nights(from: start, to: end).map { night in
            [
                CSVWriter.day(night.nightDate),
                CSVWriter.number(night.score),
                night.isBad ? "ja" : "nein",
                night.badReasons.map(\.label).joined(separator: ", "),
                CSVWriter.number(night.asleepMinutes),
                night.hasStages ? CSVWriter.number(night.deepMinutes) : "",
                night.hasStages ? CSVWriter.number(night.remMinutes) : "",
                night.hasStages ? CSVWriter.number(night.coreMinutes) : "",
                CSVWriter.number(night.awakeMinutes),
                CSVWriter.timestamp(night.sleepOnset),
                CSVWriter.timestamp(night.wakeTime),
                night.ratingValue.map(String.init) ?? "",
                SleepFactor.allCases.filter { night.factors.contains($0) }.map(\.label).joined(separator: ", "),
                night.note ?? "",
                NightTag.allCases.filter { night.tags.contains($0) }.map(\.label).joined(separator: ", "),
                night.excluded ? "ja" : "nein"
            ]
        }
        return CSVWriter.make(header: header, rows: rows)
    }
}
