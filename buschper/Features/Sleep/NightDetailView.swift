import CoreData
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
                    StatValue(value: "\(Int(night.score.rounded()))", caption: "Score · \(SleepGrade(score: night.score).label)")
                    Spacer()
                    StatValue(value: OnboardingView.hoursText(Int(night.asleepMinutes)), caption: "gschlafe", alignment: .trailing)
                }
                if let onset = night.sleepOnset, let wake = night.wakeTime {
                    LabeledValueRow(label: "Igschlafe – ufgwacht") {
                        Text("\(onset.formatted(date: .omitted, time: .shortened)) – \(wake.formatted(date: .omitted, time: .shortened))")
                            .monospacedDigit()
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wie erholt fühlsch di?").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    StarRating(rating: Binding(
                        get: { night.ratingValue ?? 0 },
                        set: { value in
                            app.sleep.updateRating(night, to: value)
                            app.dataDidChange()
                        }
                    ))
                }
            }

            if let c = night.components {
                Section {
                    blockHeader("Duur", c.duration, SleepScore.Weight.duration)
                    detailLine("\(OnboardingView.hoursText(Int(c.asleepMinutes))) gschlafe – voll 7–9 h, null under 5 h, ab 9½ h bis −5")
                } header: {
                    Text("Wie dr Score zämechunnt")
                }

                Section {
                    blockHeader("Kontinuität", c.continuity, continuityMax(c))
                    if let latency = c.latency {
                        componentRow("Iischlafduur", latency, SleepScore.Weight.latency,
                                     detail: "\(minutesText(c.latencyMinutes)) – voll bis \(Int(SleepScore.latencyFullMinutes)) min, null ab \(Int(SleepScore.latencyZeroMinutes)) min")
                    } else {
                        detailLine("Iischlafduur: ke „Im Bett“-Zyt i Health (Schlafplan bzw. Schlaf-Fokus) – zellt drum nid.")
                    }
                    componentRow("Wach nachem Iischlafe", c.waso, SleepScore.Weight.waso,
                                 detail: "\(minutesText(c.wasoMinutes)) – voll bis \(Int(SleepScore.wasoFullMinutes)) min, null ab \(Int(SleepScore.wasoZeroMinutes)) min")
                    componentRow("Ufwachphase > 5 min", c.awakenings, SleepScore.Weight.awakenings,
                                 detail: "\(c.awakeningCount)× – voll bis 1×, null ab 4×")
                    componentRow("Schlafeffizienz", c.efficiency, SleepScore.Weight.efficiency,
                                 detail: "\(Int(c.efficiencyPercent.rounded())) % vo dr Zyt im Bett – voll ab \(Int(SleepScore.efficiencyFullPercent)) %, null bis \(Int(SleepScore.efficiencyZeroPercent)) %")
                }

                Section {
                    if let regularity = c.regularity {
                        blockHeader("Regelmässigkeit", regularity, SleepScore.Weight.regularity)
                        detailLine("Schlafmitti \(minutesText(c.midpointDeviationMinutes)) näbem Schnitt vo de letschte 7 Nächt – voll bis \(Int(SleepScore.regularityFullMinutes)) min, null ab \(Int(SleepScore.regularityZeroMinutes)) min")
                    } else {
                        blockHeader("Regelmässigkeit", nil, SleepScore.Weight.regularity)
                        detailLine("No ke Vorgschicht – zellt ab dr zwöite Nacht.")
                    }
                }

                Section {
                    if let recovery = c.recovery {
                        blockHeader("Erholig", recovery, SleepScore.Weight.recovery)
                        detailLine("\(c.rating ?? 0) vo 5 Stärn – 1 = 0 Pünkt, 5 = 10 Pünkt")
                    } else {
                        blockHeader("Erholig", nil, SleepScore.Weight.recovery)
                        detailLine("Obe d Stärn setze – bis dahin zellt d Erholig nid.")
                    }
                } footer: {
                    Text("Fählt öppis, wärde di angere Teil uf 100 hochgrächnet. Iistufig: 85–100 guet, 70–84 solid, 50–69 iigschränkt, under 50 schlächt (eigeti Gränze, nid wüsseschaftlech normiert).")
                }
            }

            Section {
                if night.hasStages {
                    StageBar(night: night)
                } else {
                    Text("Ohni Schlafphase (z. B. nume iPhone).")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            } header: {
                Text("Schlafphase")
            } footer: {
                Text("Nume zur Info – zellt nid zum Score. Es git ke wüsseschaftleche Konsens drzue, u d Uhr schätzt d Phase nume ungfähr.")
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

    private func componentRow(_ label: String, _ points: Double, _ weight: Double, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(NumberText.oneDecimal(points)) / \(Int(weight))")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressBar(fraction: weight > 0 ? points / weight : 0, color: Theme.sleep)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func blockHeader(_ label: String, _ points: Double?, _ weight: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.headline)
                Spacer()
                Text(points.map { "\(NumberText.oneDecimal($0)) / \(Int(weight))" } ?? "– / \(Int(weight))")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressBar(fraction: weight > 0 ? (points ?? 0) / weight : 0, color: Theme.sleep)
        }
    }

    private func detailLine(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
    }

    /// Ohne „Im Bett“-Zeit zählt die Einschlafdauer nicht – der Block hat dann 22 Punkte.
    private func continuityMax(_ c: SleepScoreComponents) -> Double {
        SleepScore.Weight.waso + SleepScore.Weight.awakenings + SleepScore.Weight.efficiency
            + (c.latency == nil ? 0 : SleepScore.Weight.latency)
    }

    private func minutesText(_ minutes: Double?) -> String {
        minutes.map { "\(Int($0.rounded())) min" } ?? "–"
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
