import CoreData
import SwiftUI

/// Muster: Welche Faktoren gehen bei dir mit schlechterem Schlaf einher? (SPEC 12.4)
struct PatternsView: View {
    @Environment(AppEnvironment.self) private var app

    @State private var patterns: [FactorPattern] = []
    @State private var total = 0
    @State private var bad = 0
    @State private var excluded = 0

    private var reliable: [FactorPattern] { patterns.filter(\.isReliable) }
    private var pending: [FactorPattern] { patterns.filter { !$0.isReliable } }

    var body: some View {
        List {
            Section {
                HStack {
                    summaryValue("\(total)", "Nächt")
                    summaryValue("\(bad)", "schlächt")
                    summaryValue("\(excluded)", "usgschlosse")
                }
                Text("buschper vergliecht für jede Faktor d Nächt **mit** däm Faktor am Vortag mit de Nächt **ohni**. E Muster erschint ersch, we's i beidne Gruppe mindestens \(PatternAnalyzer.minimumNights) Nächt het.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            if !reliable.isEmpty {
                Section("Muster") {
                    ForEach(reliable) { pattern in
                        PatternRow(pattern: pattern)
                    }
                }
            }

            if !pending.isEmpty {
                Section("No z'weni Date") {
                    ForEach(pending) { pattern in
                        HStack {
                            Label(pattern.factor.label, systemImage: pattern.factor.symbolName)
                            Spacer()
                            Text(progressText(pattern))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    ThresholdSettingsView()
                } label: {
                    Label("Schwälle aapasse", systemImage: "slider.horizontal.3")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("E Zämehang isch no ke Beweis für e Ursach. Aber was sech immer widerholt, isch es Usprobiere wärt – z. B. e Wuche ohni Alkohol.")
                    MedicalDisclaimer()
                }
            }
        }
        .themedList()
        .navigationTitle("Muster")
        .task(id: app.revision) { load() }
    }

    private func summaryValue(_ value: String, _ caption: String) -> some View {
        StatValue(value: value, caption: caption, alignment: .center)
            .frame(maxWidth: .infinity)
    }

    private func progressText(_ pattern: FactorPattern) -> String {
        let minimum = PatternAnalyzer.minimumNights
        if pattern.nightsWith < minimum {
            return "\(pattern.nightsWith) vo \(minimum) Nächt mit"
        }
        return "\(pattern.nightsWithout) vo \(minimum) Nächt ohni"
    }

    private func load() {
        let end = DayMath.nextDay(of: Date())
        let start = Calendar.current.date(byAdding: .day, value: -365, to: end) ?? end
        let nights = app.store.nights(from: start, to: end)
        total = nights.count
        bad = nights.filter(\.isBad).count
        excluded = nights.filter(\.excluded).count
        patterns = PatternAnalyzer.patterns(from: nights.map(\.sample))
    }
}

/// Ein verlässliches Muster mit Klartext und Vergleichsbalken.
struct PatternRow: View {
    let pattern: FactorPattern

    /// Unter 3 Punkten Unterschied ist es kein erwähnenswerter Zusammenhang.
    private var isNotable: Bool { (pattern.scoreDrop ?? 0) >= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(pattern.factor.label, systemImage: pattern.factor.symbolName)
                    .font(.headline)
                Spacer()
                if let drop = pattern.scoreDrop {
                    Text(drop >= 0 ? "−\(Int(drop.rounded())) Pünkt" : "+\(Int((-drop).rounded())) Pünkt")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isNotable ? Theme.bad : Theme.textSecondary)
                }
            }
            Text(sentence)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            comparisonBar("Mit", pattern.averageWith, pattern.nightsWith, highlighted: isNotable)
            comparisonBar("Ohni", pattern.averageWithout, pattern.nightsWithout, highlighted: false)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var sentence: String {
        guard let with = pattern.averageWith, let without = pattern.averageWithout else { return "" }
        let badText = "\(pattern.badWith) vo \(pattern.nightsWith) Nächt nach \(pattern.factor.label) ware schlächt"
        if isNotable {
            return "Nach „\(pattern.factor.label)“ isch dy Score im Schnitt \(Int((without - with).rounded())) Pünkt tiefer (\(Int(with.rounded())) statt \(Int(without.rounded()))). \(badText)."
        }
        return "Kei klare Zämehang: \(Int(with.rounded())) mit, \(Int(without.rounded())) ohni. \(badText)."
    }

    private func comparisonBar(_ label: String, _ average: Double?, _ nights: Int, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, alignment: .leading)
            ProgressBar(fraction: (average ?? 0) / 100, color: highlighted ? Theme.bad : Theme.sleep, height: 8)
            Text("\(Int((average ?? 0).rounded())) · \(nights) N.")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

/// Schwellen für „schlechte Nacht“ und die Faktoren (SPEC 11.4, 12.3).
struct ThresholdSettingsView: View {
    @Environment(AppEnvironment.self) private var app

    @State private var rules = BadNightRules.standard
    @State private var thresholds = FactorThresholds.standard
    @State private var loaded = false
    @State private var recomputing = false

    var body: some View {
        Form {
            Section {
                NumberField(title: "Score under", value: $rules.absoluteThreshold, unit: "Pünkt", fractionDigits: 0)
                NumberField(title: "Under em 30-Tage-Schnitt um", value: $rules.relativeDrop, unit: "Pünkt", fractionDigits: 0)
                Stepper(value: $rules.badRatingMax, in: 0...4) {
                    LabeledValueRow(label: "Stärn bis und mit") {
                        Text(rules.badRatingMax == 0 ? "nie" : "\(rules.badRatingMax)").monospacedDigit()
                    }
                }
            } header: {
                Text("Schlächti Nacht")
            } footer: {
                Text("E Nacht isch schlächt, we eis dervo zuetrifft.")
            }

            Section {
                NumberField(title: "Alkohol meh als", value: $thresholds.alcoholGrams, unit: "g", fractionDigits: 0)
                timeRow("Koffein ab", $thresholds.caffeineCutoffMinute)
                timeRow("Letschti Mahlzyt ab", $thresholds.lateMealMinute)
                percentRow("Znacht meh als (vom Tag)", $thresholds.dinnerShareMax)
                percentRow("Fett im Znacht meh als", $thresholds.dinnerFatShareMax)
                percentRow("Kalorie-Abwychig meh als", $thresholds.calorieDeviationMax)
                percentRow("Trunke weniger als (vom Ziel)", $thresholds.fluidMinShare)
                percentRow("Schritt weniger als (vom Schnitt)", $thresholds.stepsMinShare)
                NumberField(title: "Training weniger als … vor em Schlafe", value: $thresholds.workoutGapHours, unit: "h")
            } header: {
                Text("Faktore am Vortag")
            }

            Section {
                Button {
                    Task { await apply() }
                } label: {
                    if recomputing {
                        HStack { ProgressView(); Text("Wärte nöi us …") }
                    } else {
                        Text("Übernäh u aui Nächt nöi uswärte")
                    }
                }
                .disabled(recomputing)
                Button("Uf Vorgab zrügg") {
                    rules = .standard
                    thresholds = .standard
                }
            }
        }
        .themedList()
        .navigationTitle("Schwälle")
        .onAppear {
            guard !loaded else { return }
            let profile = app.store.profile()
            rules = profile.badNightRules
            thresholds = profile.factorThresholds
            loaded = true
        }
    }

    private func timeRow(_ title: String, _ minute: Binding<Double>) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(minute.wrappedValue * 60) },
                set: { date in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                    minute.wrappedValue = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    private func percentRow(_ title: String, _ share: Binding<Double>) -> some View {
        NumberField(
            title: title,
            value: Binding(get: { share.wrappedValue * 100 }, set: { share.wrappedValue = max(0, $0) / 100 }),
            unit: "%",
            fractionDigits: 0
        )
    }

    private func apply() async {
        recomputing = true
        let profile = app.store.profile()
        profile.badNightRules = rules
        profile.factorThresholds = thresholds
        profile.updatedAt = Date()
        app.dataDidChange()
        await app.sleep.refresh(days: 90)
        app.dataDidChange()
        recomputing = false
    }
}
