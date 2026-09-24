import SwiftUI

/// Eine Nacht im Detail: Score, Phasen, Vortag, Notiz (SPEC 11.5, 12.2).
struct NightDetailView: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var night: NightRecord

    @State private var note = ""
    @State private var loaded = false

    private var metrics: DayMetrics? { night.dayMetrics }
    private var thresholds: FactorThresholds { app.store.profile().factorThresholds }

    var body: some View {
        List {
            Section {
                HStack(alignment: .bottom) {
                    StatValue(value: "\(Int(night.score.rounded()))", caption: "Score")
                    Spacer()
                    StatValue(value: OnboardingView.hoursText(Int(night.asleepMinutes)), caption: "gschlafe", alignment: .trailing)
                }
                if let onset = night.sleepOnset, let wake = night.wakeTime {
                    LabeledValueRow(label: "Igschlafe – ufgwacht") {
                        Text("\(onset.formatted(date: .omitted, time: .shortened)) – \(wake.formatted(date: .omitted, time: .shortened))")
                            .monospacedDigit()
                    }
                }
                if night.hasStages {
                    StageBar(night: night)
                } else {
                    Text("Ohni Schlafphase (z. B. nume iPhone) – Tief- u REM-Schlaf zelle nid zum Score.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wie guet hesch gschlafe?").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    StarRating(rating: Binding(
                        get: { night.ratingValue ?? 0 },
                        set: { value in
                            night.ratingValue = value
                            app.sleep.classify(night)
                            app.dataDidChange()
                        }
                    ))
                }
            }

            if let components = night.components {
                Section("Wie dr Score zämechunnt") {
                    componentRow("Duur", components.duration, SleepScore.Weight.duration)
                    if let deep = components.deep { componentRow("Tiefschlaf", deep, SleepScore.Weight.deep) }
                    if let rem = components.rem { componentRow("REM", rem, SleepScore.Weight.rem) }
                    componentRow("Wachphase", components.awake, SleepScore.Weight.awake)
                    if let regularity = components.regularity {
                        componentRow("Regelmässigkeit", regularity, SleepScore.Weight.regularity)
                    }
                }
            }

            if night.isBad {
                Section("Warum schlächt?") {
                    ForEach(night.badReasons, id: \.self) { reason in
                        Label(reason.label, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }

            Section {
                if night.factors.isEmpty {
                    Label("Nüt Uffälligs am Vortag", systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(SleepFactor.allCases.filter { night.factors.contains($0) }) { factor in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(factor.label, systemImage: factor.symbolName)
                            .foregroundStyle(Theme.textPrimary)
                        if let text = FactorText.detail(factor, metrics: metrics, thresholds: thresholds) {
                            Text(text).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            } header: {
                Text("Uffällig am Vortag")
            }

            if let metrics {
                Section("Vortag i Zahle") {
                    metricRow("Ggässe", metrics.kcalEaten.map { eaten in
                        "\(NumberText.kcal(eaten)) kcal" + (metrics.kcalBudget.map { " vo \(NumberText.kcal($0))" } ?? "")
                    })
                    metricRow("Znacht", metrics.dinnerKcal.map { "\(NumberText.kcal($0)) kcal" })
                    metricRow("Letschti Mahlzyt", metrics.lastMealMinute.map(FactorText.clock))
                    metricRow("Alkohol", metrics.alcoholG.map { "\(NumberText.oneDecimal($0)) g" })
                    metricRow("Koffein", metrics.caffeineMg.map { caffeine in
                        "\(NumberText.kcal(caffeine)) mg" + (metrics.lastCaffeineMinute.map { ", zletscht \(FactorText.clock($0))" } ?? "")
                    })
                    metricRow("Trunke", metrics.fluidMl.map { fluid in
                        NumberText.volume(fluid) + (metrics.fluidGoalMl.map { " vo \(NumberText.volume($0))" } ?? "")
                    })
                    metricRow("Schritt", metrics.steps.map { NumberText.grouped($0) })
                    metricRow("Trainings", metrics.workouts.isEmpty ? nil : "\(metrics.workouts.count)")
                }
            }

            Section {
                TextField("Notiz, z. B. Stress bi dr Arbeit", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .onSubmit(saveNote)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(NightTag.allCases) { tag in
                            let active = night.tags.contains(tag)
                            Button {
                                var tags = night.tags
                                if active { tags.remove(tag) } else { tags.insert(tag) }
                                night.tags = tags
                                app.dataDidChange()
                            } label: {
                                Text(tag.label)
                            }
                            .buttonStyle(.bordered)
                            .tint(active ? Theme.sleep : Theme.textSecondary)
                        }
                    }
                }
                Toggle("Us dr Uswärtig usschliesse", isOn: Binding(
                    get: { night.excluded },
                    set: { night.excluded = $0; app.dataDidChange() }
                ))
            } header: {
                Text("Notiz")
            } footer: {
                Text("Usgschlosseni Nächt (z. B. wäg Chrankheit) zelle bi de Muster nid mit.")
            }

            Section {
                MedicalDisclaimer()
            }
        }
        .themedList()
        .navigationTitle(night.nightDate?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? "Nacht")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            note = night.note ?? ""
            loaded = true
        }
        .onDisappear(perform: saveNote)
    }

    private func saveNote() {
        guard loaded, note != (night.note ?? "") else { return }
        night.note = note
        app.dataDidChange()
    }

    private func componentRow(_ label: String, _ points: Double, _ weight: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(NumberText.oneDecimal(points)) / \(Int(weight))")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressBar(fraction: weight > 0 ? points / weight : 0, color: Theme.sleep)
        }
    }

    private func metricRow(_ label: String, _ value: String?) -> some View {
        LabeledValueRow(label: label) {
            Text(value ?? "–")
                .monospacedDigit()
                .foregroundStyle(value == nil ? Theme.textTertiary : Theme.textPrimary)
        }
    }
}

/// Erklärende Texte zu den Faktoren.
enum FactorText {
    static func clock(_ minute: Double) -> String {
        let total = Int(minute.rounded()) % (24 * 60)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func detail(_ factor: SleepFactor, metrics: DayMetrics?, thresholds: FactorThresholds) -> String? {
        guard let metrics else { return nil }
        switch factor {
        case .alcohol:
            return metrics.alcoholG.map { "\(NumberText.oneDecimal($0)) g Alkohol" }
        case .lateCaffeine:
            return metrics.lastCaffeineMinute.map { "Letschts Koffein am \(clock($0)), Gränze \(clock(thresholds.caffeineCutoffMinute))" }
        case .lateMeal:
            return metrics.lastMealMinute.map { "Letschti Mahlzyt am \(clock($0)), Gränze \(clock(thresholds.lateMealMinute))" }
        case .heavyDinner:
            guard let dinner = metrics.dinnerKcal else { return nil }
            var parts = ["Znacht \(NumberText.kcal(dinner)) kcal"]
            if let total = metrics.kcalEaten, total > 0 {
                parts.append("\(Int((dinner / total * 100).rounded())) % vom Tag")
            }
            if let fat = metrics.dinnerFatG, dinner > 0 {
                parts.append("\(Int((fat * 9 / dinner * 100).rounded())) % us Fett")
            }
            return parts.joined(separator: " · ")
        case .calorieImbalance:
            guard let eaten = metrics.kcalEaten, let budget = metrics.kcalBudget, budget > 0 else { return nil }
            let percent = Int(((eaten - budget) / budget * 100).rounded())
            return "\(NumberText.kcal(eaten)) vo \(NumberText.kcal(budget)) kcal (\(percent > 0 ? "+" : "")\(percent) %)"
        case .lowFluid:
            guard let fluid = metrics.fluidMl, let goal = metrics.fluidGoalMl, goal > 0 else { return nil }
            return "\(NumberText.volume(fluid)) vo \(NumberText.volume(goal))"
        case .lowActivity:
            guard let steps = metrics.steps, let average = metrics.stepsAverage30 else { return nil }
            return "\(NumberText.grouped(steps)) Schritt, Schnitt \(NumberText.grouped(average))"
        case .lateWorkout:
            guard let onset = metrics.sleepOnset,
                  let last = metrics.workouts.filter(\.isIntense).map(\.end).max()
            else { return nil }
            let minutes = Int(onset.timeIntervalSince(last) / 60)
            return "Intensivs Training \(minutes) min vor em Iischlafe"
        }
    }
}
