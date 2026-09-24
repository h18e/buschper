import CoreData
import Foundation
import Observation
import SwiftUI

/// Hält alle Dienste zusammen und wird einmal in die Umgebung gelegt.
///
/// `revision` wird bei jeder Datenänderung hochgezählt. Bildschirme, die Werte aus
/// Apple Health dazuholen (und deshalb nicht allein von `@FetchRequest` leben),
/// laden damit neu.
@MainActor
@Observable
final class AppEnvironment {
    let persistence: PersistenceController
    let preferences: AppPreferences
    let store: DataStore
    let health: HealthDataProviding
    let healthSync: HealthSyncService
    let dayData: DayDataService
    let sleep: SleepService
    let widget: WidgetUpdater
    let notifications: NotificationScheduler

    private(set) var revision = 0

    init(persistence: PersistenceController, preferences: AppPreferences, health: HealthDataProviding) {
        self.persistence = persistence
        self.preferences = preferences
        self.health = health
        let store = DataStore(persistence: persistence, preferences: preferences)
        self.store = store
        self.healthSync = HealthSyncService(store: store, health: health)
        let dayData = DayDataService(store: store, health: health)
        self.dayData = dayData
        self.sleep = SleepService(store: store, health: health, dayData: dayData)
        self.widget = WidgetUpdater(store: store, dayData: dayData, preferences: preferences)
        self.notifications = NotificationScheduler(store: store, preferences: preferences)
    }

    static let live = AppEnvironment(
        persistence: .shared,
        preferences: .shared,
        health: HealthKitService()
    )

    /// Nach jeder Änderung aufrufen: speichert, lädt abhängige Anzeigen neu und
    /// schreibt offene Aufträge nach Health.
    func dataDidChange() {
        store.save()
        revision += 1
        Task {
            await healthSync.processPending()
            await widget.refresh()
            await notifications.refresh()
        }
    }

    /// Beim Wechsel in den Vordergrund: Health kann sich inzwischen geändert haben
    /// (Schritte, Schlaf, Waage), und offene Aufträge sollen raus.
    func appBecameActive() async {
        widget.importPendingWater()
        revision += 1
        await healthSync.processPending()
        await widget.refresh()
        await notifications.refresh()
        // Nach dem Aufwachen: die letzten Nächte auswerten.
        await sleep.refresh(days: 3)
        revision += 1
    }
}
