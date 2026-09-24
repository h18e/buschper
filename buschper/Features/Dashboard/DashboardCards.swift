import SwiftUI

// MARK: - Kalorien & Makros

struct EnergyCard: View {
    let snapshot: DashboardSnapshot

    private var budget: EnergyCalculator.Budget { snapshot.targets.budget }
    private var macros: MacroTargets { snapshot.targets.macros }
    private var eaten: Nutrients { snapshot.eaten.values }
    private var incomplete: Set<Nutrients.Field> { snapshot.eaten.incompleteFields }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.kcalLeft >= 0 ? "No übrig" : "Drüber")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(NumberText.kcal(abs(snapshot.kcalLeft))) kcal")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 36, height: 36)
                    .background(Theme.nutrition, in: Circle())
                    .accessibilityHidden(true)
            }

            TargetTile(title: "Kalorie", value: snapshot.eaten.kcal, target: budget.total, color: Theme.nutrition)

            HStack(spacing: 8) {
                TargetTile(title: "KH", value: eaten.carbs ?? 0, target: macros.carbsG, unit: "g",
                           color: Theme.carbs, incomplete: incomplete.contains(.carbs))
                TargetTile(title: "Eiwiss", value: eaten.protein ?? 0, target: macros.proteinG, unit: "g",
                           color: Theme.protein, incomplete: incomplete.contains(.protein))
                TargetTile(title: "Fett", value: eaten.fat ?? 0, target: macros.fatG, unit: "g",
                           color: Theme.fat, incomplete: incomplete.contains(.fat))
                TargetTile(title: "Fasere", value: eaten.fiber ?? 0, target: macros.fiberMinG, unit: "g",
                           color: Theme.fiber, incomplete: incomplete.contains(.fiber))
            }

            HStack(spacing: 6) {
                Text("Grundumsatz \(NumberText.kcal(budget.bmr)) + aktiv \(NumberText.kcal(budget.activeKcal)) \(budget.goalOffset < 0 ? "−" : "+") \(NumberText.kcal(abs(budget.goalOffset)))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                if budget.activeIsEstimate {
                    BadgeView(text: "Schätzig", color: Theme.warning, systemImage: "applewatch.slash")
                }
                if budget.minimumApplied {
                    BadgeView(text: "Undergränze", color: Theme.warning)
                }
            }
        }
        .card(tint: Theme.nutrition)
    }
}

// MARK: - Tagesliste

struct DayLogCard: View {
    let snapshot: DashboardSnapshot
    let onSelect: (DayLogItem) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tagesliste")
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Label("Ässe", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.nutrition)
            }

            if snapshot.log.isEmpty {
                Text("No nüt erfasst.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 8)
            } else if snapshot.log.count <= 4 {
                entries
            } else {
                // Eigener, scrollbarer Bereich, damit ein voller Tag das Dashboard
                // nicht in die Länge zieht (Q22).
                ScrollView {
                    entries
                }
                .frame(height: 300)
                .scrollIndicators(.visible)
            }
        }
        .card(tint: Theme.nutrition)
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(snapshot.log) { item in
                Button { onSelect(item) } label: { row(item) }
                    .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: DayLogItem) -> some View {
        switch item {
        case .meal(let meal):
            HStack(alignment: .top, spacing: 10) {
                icon(meal.category.symbolName, Theme.nutrition)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(meal.displayTitle).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(time(meal.timestamp)).font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    Text(meal.entryList.map(\.displayName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                    let sum = meal.nutrientSum
                    NutrientLine(nutrients: sum.values, incomplete: sum.incompleteFields)
                }
            }
        case .drink(let drink):
            HStack(alignment: .top, spacing: 10) {
                icon(drink.drinkType.symbolName, Theme.fluid)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(drink.displayName) · \(NumberText.volume(drink.volumeMl))")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(time(drink.timestamp)).font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    NutrientLine(nutrients: drink.total)
                }
            }
        case .workout(let workout):
            HStack(alignment: .top, spacing: 10) {
                icon(workout.sport.symbolName, Theme.activity)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(workout.sport.label).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(time(workout.start)).font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                    Text([
                        workout.kcal.map { "\(NumberText.kcal($0)) kcal verbrönnt" },
                        "\(Int(workout.durationMinutes.rounded())) min",
                        workout.sourceName
                    ].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func icon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }

    private func time(_ date: Date?) -> String {
        date?.formatted(date: .omitted, time: .shortened) ?? ""
    }
}

// MARK: - Flüssigkeit

struct FluidCard: View {
    let snapshot: DashboardSnapshot
    let range: ChartRange
    let quickMl: Double
    let onQuickAdd: () -> Void
    let onAdd: () -> Void

    private var fraction: Double {
        snapshot.targets.fluidGoalMl > 0 ? snapshot.fluidMl / snapshot.targets.fluidGoalMl : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Flüssigkeit", subtitle: "\(snapshot.drinkCount) \(snapshot.drinkCount == 1 ? "Getränk" : "Getränk")",
                       symbol: "drop.fill", color: Theme.fluid)
            HStack(alignment: .bottom) {
                BottleRow(fraction: fraction)
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NumberText.volume(snapshot.fluidMl))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("\(Int((fraction * 100).rounded())) % vo \(NumberText.volume(snapshot.targets.fluidGoalMl))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            HStack {
                Button(action: onQuickAdd) {
                    Label("+\(NumberText.volume(quickMl)) Wasser", systemImage: "drop.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.fluid)
                Button(action: onAdd) {
                    Label("Angers", systemImage: "cup.and.saucer.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Theme.fluid)
            }
            FluidChart(history: snapshot.fluidHistory, goalMl: snapshot.targets.fluidGoalMl, days: range.days)
        }
        .card(tint: Theme.fluid)
    }
}

/// Acht Flaschen, gefüllt nach Anteil am Ziel – wie im Vorbild-Screenshot.
struct BottleRow: View {
    let fraction: Double
    private let count = 8

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                let fill = min(1, max(0, fraction * Double(count) - Double(index)))
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.track)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.fluid)
                        .frame(height: 38 * fill)
                }
                .frame(width: 13, height: 38)
                .overlay(alignment: .top) {
                    Capsule().fill(fill >= 1 ? Theme.fluid : Theme.track).frame(width: 6, height: 3).offset(y: -4)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((fraction * 100).rounded())) Prozent vom Ziel")
    }
}

// MARK: - Aktivität

struct ActivityCard: View {
    let snapshot: DashboardSnapshot

    private var steps: Double { snapshot.steps ?? 0 }
    private var level: ActivityLevel { ActivityLevel(steps: steps) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Aktivität", subtitle: level.label, symbol: "figure.walk", color: Theme.activity)
            HStack(alignment: .bottom) {
                StatValue(value: NumberText.grouped(steps), caption: "Schritt")
                Spacer()
                StatValue(value: snapshot.stepsAverage30.map { NumberText.grouped($0) } ?? "–",
                          caption: "Schnitt 30 Täg", alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressBar(fraction: snapshot.stepGoal > 0 ? steps / snapshot.stepGoal : 0, color: Theme.activity, height: 6)
                Text("Ziel \(NumberText.grouped(snapshot.stepGoal))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: 16) {
                Label("\(NumberText.kcal(snapshot.activeKcal ?? 0)) kcal aktiv", systemImage: "flame")
                Label("\(Int((snapshot.exerciseMinutes ?? 0).rounded())) min Training", systemImage: "timer")
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
            if snapshot.steps == nil {
                Text("Kener Schrittdate us Apple Health.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .card(tint: Theme.activity)
    }
}

// MARK: - Gewicht

struct WeightCard: View {
    let snapshot: DashboardSnapshot
    let range: ChartRange
    var target: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Gwicht", subtitle: range.label, symbol: "scalemass.fill", color: Theme.weight)
            if snapshot.weightDaily.isEmpty {
                Text("I däm Zytruum kener Wärt. Tipp uf d Charte, zum eis z erfasse.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                HStack(alignment: .bottom) {
                    StatValue(value: WeightMath.latest(snapshot.weightDaily).map { NumberText.oneDecimal($0.kg) } ?? "–",
                              caption: "Kilo")
                    Spacer()
                    StatValue(value: WeightMath.change(snapshot.weightDaily).map { ($0 > 0 ? "+" : "") + NumberText.oneDecimal($0) } ?? "–",
                              caption: "Veränderig", alignment: .trailing)
                }
                WeightChart(daily: snapshot.weightDaily, average: snapshot.weightAverage, days: range.days, target: target)
            }
        }
        .card(tint: Theme.weight)
    }
}

// MARK: - Schlaf

struct SleepCard: View {
    let snapshot: DashboardSnapshot
    let range: ChartRange
    let threshold: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Schlaf", subtitle: range.label, symbol: "moon.zzz.fill", color: Theme.sleep)
            if let night = snapshot.lastNight {
                HStack(alignment: .bottom) {
                    StatValue(value: "\(Int(night.score.rounded()))", caption: "Score letschti Nacht")
                    Spacer()
                    StatValue(value: OnboardingView.hoursText(Int(night.asleepMinutes)), caption: "gschlafe", alignment: .trailing)
                }
                if night.isBad {
                    BadgeView(text: "Schlächti Nacht", color: Theme.bad, systemImage: "exclamationmark.triangle.fill")
                }
            }
            if snapshot.sleepHistory.isEmpty {
                Text("No kener Schlafdate. Si chöme us Apple Health, sobald d Uhr i dr Nacht treit wird.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                SleepScoreChart(nights: snapshot.sleepHistory, days: range.days, threshold: threshold)
            }
        }
        .card(tint: Theme.sleep)
    }
}

// MARK: - Wochenschnitt

struct WeekAverageCard: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Wuchenschnitt", subtitle: "\(snapshot.weekDaysWithEntries) vo 7 Täg erfasst",
                       symbol: "calendar", color: Theme.nutrition)
            if let kcal = snapshot.weekKcalAverage {
                TargetTile(title: "Kalorie pro Tag", value: kcal, target: snapshot.weekBudgetAverage, color: Theme.nutrition)
                HStack(spacing: 8) {
                    averageTile("KH", snapshot.weekMacroAverage.carbs, Theme.carbs)
                    averageTile("Eiwiss", snapshot.weekMacroAverage.protein, Theme.protein)
                    averageTile("Fett", snapshot.weekMacroAverage.fat, Theme.fat)
                    averageTile("Fasere", snapshot.weekMacroAverage.fiber, Theme.fiber)
                }
            } else {
                Text("No kener Iiträg i de letschte 7 Täg.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .card(tint: Theme.nutrition)
    }

    private func averageTile(_ title: String, _ value: Double?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Text(value.map { "\(NumberText.kcal($0)) g" } ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
