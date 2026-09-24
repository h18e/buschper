import CoreData
import Foundation

/// Ein Eintrag der Tagesliste: Mahlzeit, kalorienhaltiges Getränk oder Training.
enum DayLogItem: Identifiable {
    case meal(Meal)
    case drink(DrinkEntry)
    case workout(DayWorkout)

    var id: String {
        switch self {
        case .meal(let meal): return "meal-\(meal.objectID.uriRepresentation().absoluteString)"
        case .drink(let drink): return "drink-\(drink.objectID.uriRepresentation().absoluteString)"
        case .workout(let workout): return "workout-\(workout.id)"
        }
    }

    var time: Date {
        switch self {
        case .meal(let meal): return meal.timestamp ?? .distantPast
        case .drink(let drink): return drink.timestamp ?? .distantPast
        case .workout(let workout): return workout.start
        }
    }
}

struct DailyValue: Identifiable, Equatable {
    var day: Date
    var value: Double
    var id: Date { day }
}

/// Alles, was das Dashboard für einen Tag zeigt (SPEC 13).
struct DashboardSnapshot {
    var day: Date
    var targets: DailyTargets
    var eaten: NutrientSum
    var log: [DayLogItem]
    var fluidMl: Double
    var drinkCount: Int
    var fluidHistory: [DailyValue]
    var steps: Double?
    var stepsAverage30: Double?
    var activeKcal: Double?
    var exerciseMinutes: Double?
    var stepGoal: Double
    var weightDaily: [DailyWeight]
    var weightAverage: [DailyWeight]
    var sleepHistory: [NightRecord]
    var lastNight: NightRecord?
    var weekKcalAverage: Double?
    var weekMacroAverage: Nutrients
    var weekBudgetAverage: Double?
    var weekDaysWithEntries: Int

    var kcalLeft: Double { targets.budget.total - eaten.kcal }
}

@MainActor
final class DashboardLoader {
    private let app: AppEnvironment
    private let calendar: Calendar

    init(app: AppEnvironment, calendar: Calendar = .current) {
        self.app = app
        self.calendar = calendar
    }

    private var store: DataStore { app.store }

    func load(day: Date, range: ChartRange) async -> DashboardSnapshot {
        let start = calendar.startOfDay(for: day)
        let end = DayMath.nextDay(of: start, calendar: calendar)
        let rangeStart = calendar.date(byAdding: .day, value: -(range.days - 1), to: start) ?? start

        let targets = await app.dayData.targets(for: day)

        // Ernährung und Getränke
        let meals = store.meals(on: day)
        let drinks = store.drinks(on: day)
        let eaten = NutrientSum(meals.flatMap(\.entryList).map(\.total) + drinks.map(\.total))

        // Tagesliste
        let workouts = await app.dayData.workouts(on: day)
        var log: [DayLogItem] = meals.map { .meal($0) }
        log += drinks.filter { ($0.total.kcal ?? 0) > 0 }.map { .drink($0) }
        log += workouts.map { .workout($0) }
        log.sort { $0.time < $1.time }

        // Flüssigkeit
        let fluid = drinks.reduce(0) { $0 + $1.fluidMl }
        let rangeDrinks = store.drinks(from: rangeStart, to: end)
        var fluidByDay: [Date: Double] = [:]
        for drink in rangeDrinks {
            guard let time = drink.timestamp else { continue }
            fluidByDay[calendar.startOfDay(for: time), default: 0] += drink.fluidMl
        }
        let fluidHistory = DayMath.days(from: rangeStart, through: start, calendar: calendar)
            .map { DailyValue(day: $0, value: fluidByDay[$0] ?? 0) }

        // Aktivität
        let steps = await app.health.steps(on: day)
        let stepsStart = calendar.date(byAdding: .day, value: -30, to: start) ?? start
        let stepHistory = await app.health.dailySteps(from: stepsStart, to: calendar.date(byAdding: .day, value: -1, to: start) ?? start)
        let stepsAverage = DayMath.average(Array(stepHistory.values).filter { $0 > 0 })
        let active = await app.health.activeEnergy(on: day)
        let exercise = await app.health.exerciseMinutes(on: day)

        // Gewicht
        let weightDaily = await app.dayData.dailyWeights(from: rangeStart, to: end)
        let averageSource = await app.dayData.dailyWeights(
            from: calendar.date(byAdding: .day, value: -6, to: rangeStart) ?? rangeStart, to: end)
        let weightAverage = WeightMath.movingAverage(averageSource, calendar: calendar)
            .filter { $0.day >= rangeStart }

        // Schlaf
        let nights = store.nights(from: rangeStart, to: end)
        let lastNight = nights.last { calendar.isDate($0.nightDate ?? .distantPast, inSameDayAs: start) }

        // Wochenschnitt (7 Tage bis und mit dem gewählten Tag)
        let week = await weekAverages(endingAt: start)

        return DashboardSnapshot(
            day: start,
            targets: targets,
            eaten: eaten,
            log: log,
            fluidMl: fluid,
            drinkCount: drinks.count,
            fluidHistory: fluidHistory,
            steps: steps,
            stepsAverage30: stepsAverage,
            activeKcal: active,
            exerciseMinutes: exercise,
            stepGoal: Double(store.profile().stepGoal),
            weightDaily: weightDaily,
            weightAverage: weightAverage,
            sleepHistory: nights,
            lastNight: lastNight,
            weekKcalAverage: week.kcal,
            weekMacroAverage: week.macros,
            weekBudgetAverage: week.budget,
            weekDaysWithEntries: week.days
        )
    }

    /// Schnitt nur über Tage, an denen etwas erfasst wurde – ein vergessener Tag
    /// soll den Schnitt nicht nach unten ziehen.
    private func weekAverages(endingAt day: Date) async -> (kcal: Double?, macros: Nutrients, budget: Double?, days: Int) {
        var totals: [Nutrients] = []
        var budgets: [Double] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            let meals = store.meals(on: date)
            let drinks = store.drinks(on: date)
            guard !meals.isEmpty || drinks.contains(where: { ($0.total.kcal ?? 0) > 0 }) else { continue }
            totals.append(NutrientSum(meals.flatMap(\.entryList).map(\.total) + drinks.map(\.total)).values)
            budgets.append(await app.dayData.targets(for: date, now: Date()).budget.total)
        }
        guard !totals.isEmpty else { return (nil, Nutrients(), nil, 0) }
        let sum = NutrientSum(totals).values
        let count = Double(totals.count)
        return (
            (sum.kcal ?? 0) / count,
            sum.scaled(by: 1 / count),
            DayMath.average(budgets),
            totals.count
        )
    }
}

extension DataStore {
    func nights(from start: Date, to end: Date) -> [NightRecord] {
        fetch(
            NightRecord.self,
            predicate: DataStore.rangePredicate("nightDate", from: start, to: end),
            sort: [NSSortDescriptor(key: "nightDate", ascending: true)]
        )
    }
}
