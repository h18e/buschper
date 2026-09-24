import Foundation
import WidgetKit

/// Hält das Widget aktuell und übernimmt Wasser, das im Widget angetippt wurde.
@MainActor
final class WidgetUpdater {
    private let store: DataStore
    private let dayData: DayDataService
    private let preferences: AppPreferences

    init(store: DataStore, dayData: DayDataService, preferences: AppPreferences) {
        self.store = store
        self.dayData = dayData
        self.preferences = preferences
    }

    /// Gläser aus dem Widget als echte Einträge anlegen. `true`, wenn es welche gab.
    @discardableResult
    func importPendingWater() -> Bool {
        let pending = WidgetBridge.takePendingWater()
        guard !pending.isEmpty else { return false }
        for glass in pending {
            store.addWater(ml: glass.ml, at: glass.date)
        }
        store.save()
        return true
    }

    func refresh() async {
        let today = Date()
        let targets = await dayData.targets(for: today)
        let meals = store.meals(on: today)
        let drinks = store.drinks(on: today)
        let eaten = NutrientSum(meals.flatMap(\.entryList).map(\.total) + drinks.map(\.total)).values
        let snapshot = WidgetSnapshot(
            day: Calendar.current.startOfDay(for: today),
            kcalEaten: eaten.kcal ?? 0,
            kcalBudget: targets.budget.total,
            carbs: eaten.carbs ?? 0,
            protein: eaten.protein ?? 0,
            fat: eaten.fat ?? 0,
            carbsTarget: targets.macros.carbsG,
            proteinTarget: targets.macros.proteinG,
            fatTarget: targets.macros.fatG,
            fluidMl: drinks.reduce(0) { $0 + $1.fluidMl },
            fluidGoalMl: targets.fluidGoalMl,
            quickWaterMl: preferences.quickWaterMl,
            updatedAt: Date()
        )
        WidgetBridge.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetBridge.widgetKind)
    }
}
