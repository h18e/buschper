import Foundation

/// Beispieldaten für SwiftUI-Vorschauen. Die App selbst benutzt immer
/// `HealthKitService` – auch im Simulator, dort mit leerer Health-Datenbank.
final class DemoHealthSource: HealthDataProviding {
    var isAvailable: Bool { true }

    func requestAuthorization() async -> Bool { true }

    func profileData() async -> HealthProfileData {
        HealthProfileData(
            birthDate: Calendar.current.date(from: DateComponents(year: 1982, month: 5, day: 14)),
            sex: .male,
            heightCm: 181,
            latestWeightKg: 79.4
        )
    }

    func activeEnergy(on day: Date) async -> Double? { 430 }
    func steps(on day: Date) async -> Double? { 6319 }

    func dailySteps(from start: Date, to end: Date) async -> [Date: Double] {
        var result: [Date: Double] = [:]
        for (index, day) in DayMath.days(from: start, through: end).enumerated() {
            result[day] = Double(3500 + (index * 1379) % 7000)
        }
        return result
    }

    func exerciseMinutes(on day: Date) async -> Double? { 34 }

    func workouts(from start: Date, to end: Date) async -> [HealthWorkout] {
        let begin = Calendar.current.date(byAdding: .hour, value: 7, to: Calendar.current.startOfDay(for: start)) ?? start
        return [
            HealthWorkout(id: UUID(), start: begin, end: begin.addingTimeInterval(45 * 60), sport: .walking,
                          kcal: 180, averageHeartRate: 104, isOwn: false, sourceName: "Apple Watch")
        ]
    }

    func foreignWeights(from start: Date, to end: Date) async -> [HealthWeight] {
        DayMath.days(from: start, through: end).enumerated().map { index, day in
            HealthWeight(id: UUID(), date: day.addingTimeInterval(7 * 3600),
                         kg: 80.8 - Double(index) * 0.05, sourceName: "Waage")
        }
    }

    func sleepSamples(from start: Date, to end: Date) async -> [HealthSleepSample] { [] }

    func saveNutrition(localId: UUID, date: Date, name: String, total: Nutrients) async throws {}
    func saveWater(localId: UUID, date: Date, ml: Double) async throws {}
    func saveWeight(localId: UUID, date: Date, kg: Double) async throws {}
    func saveWorkout(localId: UUID, start: Date, end: Date, sport: SportType, kcal: Double) async throws {}
    func deleteOwnSamples(localId: UUID) async {}
}

extension AppEnvironment {
    /// Für Vorschauen: Arbeitsspeicher-Datenbank und Beispiel-Health.
    static func preview() -> AppEnvironment {
        let environment = AppEnvironment(
            persistence: PersistenceController(role: .inMemory),
            preferences: AppPreferences(defaults: UserDefaults(suiteName: "buschper.preview") ?? .standard),
            health: DemoHealthSource()
        )
        let profile = environment.store.profile()
        profile.onboardingCompleted = true
        profile.birthDate = Calendar.current.date(from: DateComponents(year: 1982, month: 5, day: 14))
        profile.heightCm = 181
        profile.goal = .lose
        environment.store.save()
        return environment
    }
}
