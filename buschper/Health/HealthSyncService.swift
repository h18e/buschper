import CoreData
import Foundation
import os

/// Arbeitet offene Health-Aufträge dieses Geräts ab (SPEC 8.3).
///
/// Jede Änderung an einem eigenen Eintrag setzt nur eine Markierung
/// (`DataStore.markForHealthWrite`). Dieser Dienst schreibt dann: erst alles
/// löschen, was buschper zu diesem Eintrag schon in Health hat, dann neu schreiben.
/// So ist Ändern dasselbe wie Neu-Erfassen, und ein abgebrochener Durchlauf wird
/// beim nächsten Mal einfach wiederholt.
@MainActor
final class HealthSyncService {
    private let store: DataStore
    private let health: HealthDataProviding
    private var isRunning = false
    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "HealthSync")

    init(store: DataStore, health: HealthDataProviding) {
        self.store = store
        self.health = health
    }

    func processPending() async {
        guard health.isAvailable, !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        for link in store.pendingHealthLinks() {
            guard let localId = link.localId,
                  let kind = HealthSampleKind(rawValue: link.localKindRaw ?? "")
            else {
                store.context.delete(link)
                continue
            }

            await health.deleteOwnSamples(localId: localId)

            if link.pendingDelete {
                store.context.delete(link)
                store.save()
                continue
            }

            do {
                try await write(kind: kind, localId: localId)
                link.pendingWrite = false
                link.updatedAt = Date()
            } catch {
                // Bleibt markiert und wird beim nächsten Start erneut versucht.
                Self.logger.error("Health-Schreiben fehlgeschlagen: \(error.localizedDescription)")
            }
            store.save()
        }
    }

    private func write(kind: HealthSampleKind, localId: UUID) async throws {
        switch kind {
        case .meal:
            guard let meal = store.object(Meal.self, id: localId), let date = meal.timestamp else { return }
            let total = meal.nutrientSum.values
            try await health.saveNutrition(localId: localId, date: date, name: meal.displayTitle, total: total)

        case .water:
            guard let drink = store.object(DrinkEntry.self, id: localId), let date = drink.timestamp else { return }
            try await health.saveWater(localId: localId, date: date, ml: drink.fluidMl)
            // Kalorienhaltige Getränke erscheinen in Health auch als Nahrung.
            let total = drink.total
            if (total.kcal ?? 0) > 0 || (total.caffeine ?? 0) > 0 {
                try await health.saveNutrition(localId: localId, date: date, name: drink.displayName, total: total)
            }

        case .weight:
            guard let entry = store.object(WeightEntry.self, id: localId), let date = entry.timestamp else { return }
            try await health.saveWeight(localId: localId, date: date, kg: entry.kg)

        case .workout:
            guard let workout = store.object(WorkoutEntry.self, id: localId),
                  let start = workout.start, let end = workout.end
            else { return }
            try await health.saveWorkout(localId: localId, start: start, end: end, sport: workout.sportType, kcal: workout.kcal)
        }
    }
}
