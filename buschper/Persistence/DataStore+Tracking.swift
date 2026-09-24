import CoreData
import Foundation

/// Entwurf eines Getränks (SPEC 7).
struct DrinkDraft: Equatable {
    var timestamp = Date()
    var drinkType: DrinkType = .water
    var name = ""
    var volumeMl: Double = 250
    var abvPercent: Double = 0
    var countsAsFluid = true
    /// Richtwerte pro 100 ml, ohne Alkohol (der kommt aus Vol-%).
    var per100ml = Nutrients(kcal: 0)
    var presetId: String?

    init() {}

    init(type: DrinkType, at date: Date = Date()) {
        timestamp = date
        apply(type: type)
    }

    init(preset: DrinkPreset, at date: Date = Date()) {
        timestamp = date
        drinkType = preset.drinkType
        name = preset.name ?? ""
        volumeMl = preset.volumeMl
        abvPercent = preset.abvPercent
        countsAsFluid = preset.drinkType.countsAsFluidByDefault
        per100ml = preset.per100
        presetId = preset.id?.uuidString
    }

    init(entry: DrinkEntry) {
        timestamp = entry.timestamp ?? Date()
        drinkType = entry.drinkType
        name = entry.name ?? ""
        volumeMl = entry.volumeMl
        abvPercent = entry.abvPercent
        countsAsFluid = entry.countsAsFluid
        // Pro 100 ml zurückrechnen, ohne den Alkoholanteil.
        var total = entry.total
        let alcohol = DrinkMath.alcoholGrams(volumeMl: entry.volumeMl, abvPercent: entry.abvPercent)
        if alcohol > 0 {
            total.alcohol = nil
            total.kcal = max(0, (total.kcal ?? 0) - alcohol * Nutrients.EnergyFactor.alcohol)
        }
        per100ml = entry.volumeMl > 0 ? total.scaled(by: 100 / entry.volumeMl) : total
        presetId = entry.presetId
    }

    mutating func apply(type: DrinkType) {
        drinkType = type
        volumeMl = type.defaultVolumeMl
        abvPercent = type.defaultABV
        countsAsFluid = type.countsAsFluidByDefault
        per100ml = type.defaultNutrientsPer100ml
    }

    var total: Nutrients {
        DrinkMath.totals(per100ml: per100ml, volumeMl: volumeMl, abvPercent: abvPercent)
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? drinkType.label : trimmed
    }
}

/// Entwurf eines manuellen Trainings (SPEC 10.2).
struct WorkoutDraft: Equatable {
    var start = Date().addingTimeInterval(-3600)
    var durationMinutes: Double = 45
    var sport: SportType = .walking
    var intensity: WorkoutIntensity = .moderate
    var kcal: Double = 0
    var kcalIsManual = false
    var note = ""

    init() {}

    init(entry: WorkoutEntry) {
        start = entry.start ?? Date()
        durationMinutes = entry.durationMinutes
        sport = entry.sportType
        intensity = entry.intensity
        kcal = entry.kcal
        kcalIsManual = entry.kcalIsManual
        note = entry.note ?? ""
    }

    func estimatedKcal(weightKg: Double) -> Double {
        WorkoutEstimator.kcal(sport: sport, intensity: intensity, weightKg: weightKg, durationMinutes: durationMinutes)
    }
}

extension DataStore {

    // MARK: - Getränke

    func drinks(on day: Date) -> [DrinkEntry] {
        fetch(DrinkEntry.self, predicate: DataStore.dayPredicate("timestamp", day: day),
              sort: [NSSortDescriptor(key: "timestamp", ascending: true)])
    }

    func drinks(from start: Date, to end: Date) -> [DrinkEntry] {
        fetch(DrinkEntry.self, predicate: DataStore.rangePredicate("timestamp", from: start, to: end),
              sort: [NSSortDescriptor(key: "timestamp", ascending: true)])
    }

    @discardableResult
    func saveDrink(_ draft: DrinkDraft, editing existing: DrinkEntry? = nil) -> DrinkEntry {
        let entry = existing ?? {
            let entry = DrinkEntry(context: context)
            entry.id = UUID()
            entry.createdAt = Date()
            return entry
        }()
        entry.timestamp = draft.timestamp
        entry.drinkType = draft.drinkType
        entry.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.volumeMl = max(0, draft.volumeMl)
        entry.abvPercent = max(0, draft.abvPercent)
        entry.countsAsFluid = draft.countsAsFluid
        entry.total = draft.total
        entry.presetId = draft.presetId ?? ""
        entry.updatedAt = Date()
        if let id = entry.id {
            markForHealthWrite(localId: id, kind: .water)
        }
        return entry
    }

    /// Schnelltaste: ein Glas Wasser.
    @discardableResult
    func addWater(ml: Double, at date: Date = Date()) -> DrinkEntry {
        var draft = DrinkDraft(type: .water, at: date)
        draft.volumeMl = ml
        return saveDrink(draft)
    }

    func deleteDrink(_ entry: DrinkEntry) {
        if let id = entry.id {
            markForHealthDelete(localId: id, kind: .water)
        }
        context.delete(entry)
    }

    // MARK: - Getränkevorlagen

    func drinkPresets() -> [DrinkPreset] {
        fetch(DrinkPreset.self, sort: [NSSortDescriptor(key: "sortIndex", ascending: true)])
    }

    @discardableResult
    func savePreset(from draft: DrinkDraft) -> DrinkPreset {
        let preset = DrinkPreset(context: context)
        preset.id = UUID()
        preset.name = draft.displayName
        preset.drinkType = draft.drinkType
        preset.volumeMl = draft.volumeMl
        preset.abvPercent = draft.abvPercent
        preset.per100 = draft.per100ml
        preset.sortIndex = Int32((drinkPresets().map(\.sortIndex).max() ?? -1) + 1)
        return preset
    }

    func deletePreset(_ preset: DrinkPreset) {
        context.delete(preset)
    }

    // MARK: - Gewicht

    @discardableResult
    func saveWeight(kg: Double, at date: Date, editing existing: WeightEntry? = nil) -> WeightEntry {
        let entry = existing ?? {
            let entry = WeightEntry(context: context)
            entry.id = UUID()
            entry.createdAt = Date()
            return entry
        }()
        entry.kg = kg
        entry.timestamp = date
        if let id = entry.id {
            markForHealthWrite(localId: id, kind: .weight)
        }
        return entry
    }

    func deleteWeight(_ entry: WeightEntry) {
        if let id = entry.id {
            markForHealthDelete(localId: id, kind: .weight)
        }
        context.delete(entry)
    }

    // MARK: - Trainings

    @discardableResult
    func saveWorkout(_ draft: WorkoutDraft, weightKg: Double, editing existing: WorkoutEntry? = nil) -> WorkoutEntry {
        let entry = existing ?? {
            let entry = WorkoutEntry(context: context)
            entry.id = UUID()
            entry.createdAt = Date()
            return entry
        }()
        entry.start = draft.start
        entry.durationMinutes = max(1, draft.durationMinutes)
        entry.sportType = draft.sport
        entry.intensity = draft.intensity
        entry.kcalIsManual = draft.kcalIsManual
        entry.kcal = draft.kcalIsManual ? max(0, draft.kcal) : draft.estimatedKcal(weightKg: weightKg)
        entry.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.updatedAt = Date()
        if let id = entry.id {
            markForHealthWrite(localId: id, kind: .workout)
        }
        return entry
    }

    func deleteWorkout(_ entry: WorkoutEntry) {
        if let id = entry.id {
            markForHealthDelete(localId: id, kind: .workout)
        }
        context.delete(entry)
    }
}
