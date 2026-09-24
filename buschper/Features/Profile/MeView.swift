import SwiftUI

/// Tab „Ig“: Profil, Ziele, Sammlungen und Einstellungen.
struct MeView: View {
    @Environment(AppEnvironment.self) private var app

    var body: some View {
        let profile = app.store.profile()
        NavigationStack {
            List {
                Section {
                    NeedsSummaryCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Profil u Ziel") {
                    NavigationLink {
                        ProfileEditView(profile: profile)
                    } label: {
                        Label("Profil", systemImage: "person.fill")
                    }
                    NavigationLink {
                        GoalEditView(profile: profile)
                    } label: {
                        Label("Ziel u Kalorie", systemImage: "target")
                    }
                    NavigationLink {
                        MacroEditView(profile: profile)
                    } label: {
                        Label("Makros", systemImage: "chart.pie.fill")
                    }
                    NavigationLink {
                        DailyGoalsEditView(profile: profile)
                    } label: {
                        Label("Trinke, Schritt u Schlaf", systemImage: "drop.fill")
                    }
                }
                .listRowBackground(Theme.surface)

                MeCollectionsSection()

                Section("Istellige") {
                    NavigationLink {
                        HealthSettingsView()
                    } label: {
                        Label("Apple Health", systemImage: "heart.fill")
                    }
                    NavigationLink {
                        FoodSourcesSettingsView()
                    } label: {
                        Label("Lebensmitteldatebanke", systemImage: "magnifyingglass")
                    }
                    MeSettingsExtraRows()
                }
                .listRowBackground(Theme.surface)

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Über buschper", systemImage: "info.circle")
                    }
                }
                .listRowBackground(Theme.surface)

                #if DEBUG
                DeveloperSection()
                    .listRowBackground(Theme.surface)
                #endif
            }
            .themedList()
            .navigationTitle("Ig")
        }
    }
}

/// Bedarf von heute auf einen Blick.
struct NeedsSummaryCard: View {
    @Environment(AppEnvironment.self) private var app
    @State private var targets: DailyTargets?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Bedarf hüt", subtitle: targets.map { "\(NumberText.kcal($0.budget.total)) kcal" },
                       symbol: "flame.fill", color: Theme.nutrition)
            if let targets {
                LabeledValueRow(label: "Grundumsatz") {
                    Text("\(NumberText.kcal(targets.budget.bmr)) kcal").monospacedDigit()
                }
                LabeledValueRow(label: targets.budget.activeIsEstimate ? "Aktivkalorie (Schätzig)" : "Aktivkalorie bis jetz") {
                    Text("\(NumberText.kcal(targets.budget.activeKcal)) kcal").monospacedDigit()
                }
                LabeledValueRow(label: "Ziel-Abschlag") {
                    Text("\(NumberText.kcal(targets.budget.goalOffset)) kcal").monospacedDigit()
                }
                if targets.budget.minimumApplied {
                    BadgeView(text: "Undergränze greift", color: Theme.warning, systemImage: "exclamationmark.triangle.fill")
                }
                LabeledValueRow(label: targets.weightIsFallback ? "Gwicht (us em Profil)" : "Gwicht (7-Tage-Schnitt)") {
                    Text("\(NumberText.oneDecimal(targets.weightKg)) kg").monospacedDigit()
                }
                LabeledValueRow(label: "Flüssigkeit") {
                    Text(NumberText.volume(targets.fluidGoalMl)).monospacedDigit()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .card(tint: Theme.nutrition)
        .task(id: app.revision) {
            targets = await app.dayData.targets(for: Date())
        }
    }
}

// MARK: - Profil

struct ProfileEditView: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var profile: Profile

    var body: some View {
        Form {
            Section {
                Picker("Gschlächt", selection: Binding(get: { profile.sex }, set: { profile.sex = $0 })) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                DatePicker(
                    "Geburtsdatum",
                    selection: Binding(
                        get: { profile.birthDate ?? Date() },
                        set: { profile.birthDate = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                NumberField(title: "Grössi", value: $profile.heightCm, unit: "cm", fractionDigits: 0)
            }
            Section {
                NumberField(title: "Rückfall-Gwicht", value: $profile.fallbackWeightKg, unit: "kg")
                OptionalNumberField(
                    title: "Zielgwicht",
                    value: Binding(get: { profile.targetWeight }, set: { profile.targetWeight = $0 }),
                    unit: "kg"
                )
            } footer: {
                Text("S Rückfall-Gwicht gilt nume, we i de letschte 30 Täg keis us Health oder vo Hand bekannt isch.")
            }
            Section {
                Button("Us Health übernäh") {
                    Task {
                        let data = await app.health.profileData()
                        if let birthDate = data.birthDate { profile.birthDate = birthDate }
                        if let sex = data.sex { profile.sex = sex }
                        if let height = data.heightCm, height > 0 { profile.heightCm = height.rounded() }
                        app.dataDidChange()
                    }
                }
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Profil")
        .onDisappear { app.dataDidChange() }
    }
}

// MARK: - Ziel und Kalorien

struct GoalEditView: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var profile: Profile

    var body: some View {
        Form {
            Section {
                Picker("Ziel", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                    ForEach(WeightGoal.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                ForEach(WeightGoal.allCases) { goal in
                    NumberField(
                        title: goal.label,
                        value: Binding(get: { profile.offset(for: goal) }, set: { profile.setOffset($0, for: goal) }),
                        unit: "kcal",
                        fractionDigits: 0
                    )
                }
            } header: {
                Text("Abschlag pro Tag")
            } footer: {
                Text("Wird zum Grundumsatz u de Aktivkalorie drzuezellt. S Budget faut nie under \(NumberText.kcal(EnergyCalculator.minimumBudget(for: profile.sex))) kcal.")
            }
            Section {
                Picker("Bewegigsprofil", selection: Binding(get: { profile.activityProfile }, set: { profile.activityProfile = $0 })) {
                    ForEach(ActivityProfile.allCases) { item in
                        VStack(alignment: .leading) {
                            Text(item.label)
                            Text(item.explanation).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        .tag(item)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Bewegigsprofil")
            } footer: {
                Text("Gilt nume, we Apple Health bis am Mittag kener Aktivkalorie liferet. Denn steit „Schätzig“ bim Budget.")
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Ziel u Kalorie")
        .onDisappear { app.dataDidChange() }
    }
}

// MARK: - Makros

struct MacroEditView: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var profile: Profile

    @State private var split = MacroSplit.standard
    @State private var fiber = MacroTargets.defaultFiberMinG
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                percentRow("Kohlehydrat", value: $split.carbsPercent, color: Theme.carbs)
                percentRow("Eiwiss", value: $split.proteinPercent, color: Theme.protein)
                percentRow("Fett", value: $split.fatPercent, color: Theme.fat)
                LabeledValueRow(label: "Summe") {
                    Text("\(Int(split.sum.rounded())) %")
                        .monospacedDigit()
                        .foregroundStyle(split.isValid ? Theme.good : Theme.bad)
                }
            } header: {
                Text("Verteilig vo de Kalorie")
            } footer: {
                Text(split.isValid
                     ? "D Gramm-Ziel wachse im Louf vom Tag mit em Budget mit."
                     : "Zäme müesse's genau 100 % gä. Vorhär wird nüt gspycheret.")
            }
            Section {
                NumberField(title: "Ballaststoffe mindestens", value: $fiber, unit: "g", fractionDigits: 0)
            }
            Section {
                Button("Uf Vorgab zrügg (45 / 25 / 30)") {
                    split = .standard
                }
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Makros")
        .onAppear {
            guard !loaded else { return }
            split = profile.macroSplit
            fiber = profile.fiberMinG
            loaded = true
        }
        .onChange(of: split) { _, newValue in
            if newValue.isValid {
                profile.macroSplit = newValue
                profile.updatedAt = Date()
            }
        }
        .onChange(of: fiber) { _, newValue in
            profile.fiberMinG = max(0, newValue)
        }
        .onDisappear { app.dataDidChange() }
    }

    private func percentRow(_ title: String, value: Binding<Double>, color: Color) -> some View {
        Stepper(value: value, in: 0...100, step: 1) {
            HStack {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded())) %")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Tagesziele

struct DailyGoalsEditView: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var profile: Profile

    var body: some View {
        Form {
            Section {
                Toggle("Flüssigkeitsziel vo Hand", isOn: Binding(
                    get: { profile.waterGoalOverride != nil },
                    set: { profile.waterGoalOverride = $0 ? 2500 : nil }
                ))
                if profile.waterGoalOverride != nil {
                    NumberField(
                        title: "Ziel",
                        value: Binding(get: { profile.waterGoalOverrideMl }, set: { profile.waterGoalOverrideMl = max(0, $0) }),
                        unit: "ml",
                        fractionDigits: 0
                    )
                }
            } header: {
                Text("Trinke")
            } footer: {
                Text("Ohni eigets Ziel rächnet buschper 35 ml pro kg plus 500 ml pro Trainingsstund.")
            }
            Section("Schritt") {
                Stepper(value: Binding(get: { Int(profile.stepGoal) }, set: { profile.stepGoal = Int32($0) }),
                        in: 2000...30000, step: 500) {
                    LabeledValueRow(label: "Schrittziel") {
                        Text(NumberText.grouped(Double(profile.stepGoal))).monospacedDigit()
                    }
                }
            }
            Section("Schlaf") {
                Stepper(value: Binding(get: { Int(profile.sleepGoalMinutes) }, set: { profile.sleepGoalMinutes = Int32($0) }),
                        in: 300...720, step: 15) {
                    LabeledValueRow(label: "Schlafziel") {
                        Text(OnboardingView.hoursText(Int(profile.sleepGoalMinutes))).monospacedDigit()
                    }
                }
            }
        }
        .listRowBackground(Theme.surface)
        .themedList()
        .navigationTitle("Tagesziel")
        .onDisappear { app.dataDidChange() }
    }
}
