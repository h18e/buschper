import Foundation
import HealthKit
import os

// MARK: - Was die App von Apple Health braucht

struct HealthProfileData: Equatable {
    var birthDate: Date?
    var sex: Sex?
    var heightCm: Double?
    var latestWeightKg: Double?
}

/// Gewicht aus einer fremden Quelle (Waage, andere App).
struct HealthWeight: Equatable, Identifiable {
    var id: UUID
    var date: Date
    var kg: Double
    var sourceName: String
}

/// Training aus Health.
struct HealthWorkout: Equatable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date
    var sport: SportType
    var kcal: Double?
    var averageHeartRate: Double?
    /// `true`, wenn buschper es selbst geschrieben hat (manuelles Training).
    var isOwn: Bool
    var sourceName: String

    var durationMinutes: Double { end.timeIntervalSince(start) / 60 }
}

enum SleepStage: String, Equatable {
    case inBed
    case asleep
    case core
    case deep
    case rem
    case awake
}

struct HealthSleepSample: Equatable {
    var start: Date
    var end: Date
    var stage: SleepStage
    var sourceId: String
}

/// Schnittstelle zu Apple Health. Hinter einem Protokoll, damit Vorschauen und
/// der Simulator mit Beispieldaten laufen können.
protocol HealthDataProviding: AnyObject {
    var isAvailable: Bool { get }

    func requestAuthorization() async -> Bool

    func profileData() async -> HealthProfileData
    func activeEnergy(on day: Date) async -> Double?
    func steps(on day: Date) async -> Double?
    func dailySteps(from start: Date, to end: Date) async -> [Date: Double]
    func exerciseMinutes(on day: Date) async -> Double?
    func workouts(from start: Date, to end: Date) async -> [HealthWorkout]
    func foreignWeights(from start: Date, to end: Date) async -> [HealthWeight]
    func sleepSamples(from start: Date, to end: Date) async -> [HealthSleepSample]

    func saveNutrition(localId: UUID, date: Date, name: String, total: Nutrients) async throws
    func saveWater(localId: UUID, date: Date, ml: Double) async throws
    func saveWeight(localId: UUID, date: Date, kg: Double) async throws
    func saveWorkout(localId: UUID, start: Date, end: Date, sport: SportType, kcal: Double) async throws
    func deleteOwnSamples(localId: UUID) async
}

// MARK: - Umsetzung mit HealthKit

final class HealthKitService: HealthDataProviding {
    private let store = HKHealthStore()
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "Health")

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Fragt einmal nach allen Berechtigungen. iOS zeigt den Dialog nur beim ersten
    /// Mal; danach ändert man sie in der Health-App. Ob Lesen erlaubt wurde, verrät
    /// HealthKit aus Datenschutzgründen nicht – verweigertes Lesen sieht aus wie
    /// „keine Daten“.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: HealthTypes.shareTypes, read: HealthTypes.readTypes)
            return true
        } catch {
            Self.logger.error("Health-Berechtigung fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Profil

    func profileData() async -> HealthProfileData {
        guard isAvailable else { return HealthProfileData() }
        var data = HealthProfileData()

        if let components = try? store.dateOfBirthComponents() {
            data.birthDate = calendar.date(from: components)
        }
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .male: data.sex = .male
            case .female: data.sex = .female
            default: data.sex = nil
            }
        }
        data.heightCm = await latestQuantity(HealthTypes.height, unit: .meterUnit(with: .centi), excludeOwn: false)
        data.latestWeightKg = await latestQuantity(HealthTypes.bodyMass, unit: .gramUnit(with: .kilo), excludeOwn: false)
        return data
    }

    private func latestQuantity(_ type: HKQuantityType, unit: HKUnit, excludeOwn: Bool) async -> Double? {
        let predicate: NSPredicate? = excludeOwn ? notOwnSource : nil
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.first?.quantity.doubleValue(for: unit)
    }

    // MARK: Aktivität

    func activeEnergy(on day: Date) async -> Double? {
        await daySum(HealthTypes.activeEnergy, unit: .kilocalorie(), day: day)
    }

    func steps(on day: Date) async -> Double? {
        await daySum(HealthTypes.steps, unit: .count(), day: day)
    }

    func exerciseMinutes(on day: Date) async -> Double? {
        await daySum(HealthTypes.exerciseTime, unit: .minute(), day: day)
    }

    /// Summe eines Tages. `HKStatistics` entfernt Überschneidungen zwischen
    /// iPhone und Uhr selbst – eine einfache Addition der Werte würde doppelt zählen.
    private func daySum(_ type: HKQuantityType, unit: HKUnit, day: Date) async -> Double? {
        guard isAvailable else { return nil }
        let start = calendar.startOfDay(for: day)
        let end = DayMath.nextDay(of: start, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        guard let statistics = try? await descriptor.result(for: store),
              let sum = statistics.sumQuantity()
        else { return nil }
        return sum.doubleValue(for: unit)
    }

    func dailySteps(from start: Date, to end: Date) async -> [Date: Double] {
        guard isAvailable else { return [:] }
        let first = calendar.startOfDay(for: start)
        let last = DayMath.nextDay(of: end, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: first, end: last, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HealthTypes.steps, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: first,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var result: [Date: Double] = [:]
        collection.enumerateStatistics(from: first, to: last) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                result[self.calendar.startOfDay(for: statistics.startDate)] = sum.doubleValue(for: .count())
            }
        }
        return result
    }

    func workouts(from start: Date, to end: Date) async -> [HealthWorkout] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let workouts = (try? await descriptor.result(for: store)) ?? []
        let ownBundle = HKSource.default().bundleIdentifier
        let bpm = HKUnit.count().unitDivided(by: .minute())

        return workouts.map { workout in
            HealthWorkout(
                id: workout.uuid,
                start: workout.startDate,
                end: workout.endDate,
                sport: SportType(healthActivityType: workout.workoutActivityType),
                kcal: workout.statistics(for: HealthTypes.activeEnergy)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                averageHeartRate: workout.statistics(for: HealthTypes.heartRate)?.averageQuantity()?.doubleValue(for: bpm),
                isOwn: workout.sourceRevision.source.bundleIdentifier == ownBundle,
                sourceName: workout.sourceRevision.source.name
            )
        }
    }

    // MARK: Gewicht

    func foreignWeights(from start: Date, to end: Date) async -> [HealthWeight] {
        guard isAvailable else { return [] }
        let range = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [range, notOwnSource])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HealthTypes.bodyMass, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { sample in
            HealthWeight(
                id: sample.uuid,
                date: sample.startDate,
                kg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                sourceName: sample.sourceRevision.source.name
            )
        }
    }

    // MARK: Schlaf

    func sleepSamples(from start: Date, to end: Date) async -> [HealthSleepSample] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HealthTypes.sleep, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
            let stage: SleepStage
            switch value {
            case .inBed: stage = .inBed
            case .awake: stage = .awake
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            default: stage = .asleep
            }
            return HealthSleepSample(
                start: sample.startDate,
                end: sample.endDate,
                stage: stage,
                sourceId: sample.sourceRevision.source.bundleIdentifier
            )
        }
    }

    // MARK: Schreiben

    private func metadata(localId: UUID) -> [String: Any] {
        [HealthTypes.localIdKey: localId.uuidString]
    }

    func saveNutrition(localId: UUID, date: Date, name: String, total: Nutrients) async throws {
        guard isAvailable else { return }
        let meta = metadata(localId: localId)
        var objects = Set<HKSample>()
        for mapping in HealthTypes.nutrientMappings {
            guard let value = total[mapping.field], value > 0 else { continue }
            let quantity = HKQuantity(unit: mapping.unit, doubleValue: mapping.convert(value))
            objects.insert(HKQuantitySample(type: mapping.type, quantity: quantity, start: date, end: date, metadata: meta))
        }
        guard !objects.isEmpty else { return }
        var correlationMeta = meta
        correlationMeta[HKMetadataKeyFoodType] = name
        let correlation = HKCorrelation(type: HealthTypes.food, start: date, end: date, objects: objects, metadata: correlationMeta)
        try await store.save(correlation)
    }

    func saveWater(localId: UUID, date: Date, ml: Double) async throws {
        guard isAvailable, ml > 0 else { return }
        let sample = HKQuantitySample(
            type: HealthTypes.water,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml),
            start: date,
            end: date,
            metadata: metadata(localId: localId)
        )
        try await store.save(sample)
    }

    func saveWeight(localId: UUID, date: Date, kg: Double) async throws {
        guard isAvailable, kg > 0 else { return }
        let sample = HKQuantitySample(
            type: HealthTypes.bodyMass,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date,
            metadata: metadata(localId: localId)
        )
        try await store.save(sample)
    }

    /// Schreibt ein Training samt Aktivkalorien. Die Kalorien kommen danach als
    /// Aktivkalorien zurück ins Tagesbudget (SPEC 4.2).
    func saveWorkout(localId: UUID, start: Date, end: Date, sport: SportType, kcal: Double) async throws {
        guard isAvailable, end > start else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = sport.healthActivityType
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        let meta = metadata(localId: localId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: start) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        if kcal > 0 {
            let energy = HKQuantitySample(
                type: HealthTypes.activeEnergy,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: start,
                end: end,
                metadata: meta
            )
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([energy]) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addMetadata(meta) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: end) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.finishWorkout { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    /// Löscht alles, was buschper zu einem Eintrag geschrieben hat. Fehler werden
    /// nur protokolliert: Gab es nichts zu löschen, ist das kein Problem.
    func deleteOwnSamples(localId: UUID) async {
        guard isAvailable else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthTypes.localIdKey, allowedValues: [localId.uuidString])
        var types: [HKObjectType] = [HealthTypes.food]
        types.append(contentsOf: HealthTypes.ownWrittenTypes.map { $0 as HKObjectType })
        for type in types {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.deleteObjects(of: type, predicate: predicate) { _, _, error in
                    if let error {
                        Self.logger.info("Loeschen in \(type.identifier) nicht moeglich: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: Hilfen

    /// Alles, was **nicht** von buschper stammt.
    private var notOwnSource: NSPredicate {
        NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
    }
}
