import CoreData
import SwiftUI

/// Tab „Hüt“: das Dashboard (SPEC 13).
struct TodayView: View {
    @Environment(AppEnvironment.self) private var app
    @EnvironmentObject private var preferences: AppPreferences

    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var range: ChartRange = .month
    @State private var snapshot: DashboardSnapshot?
    @State private var sheet: Sheet?

    enum Sheet: Identifiable {
        case editLayout
        case addFood
        case addDrink
        case addWeight
        case meal(Meal)
        case drink(DrinkEntry)
        case workout(WorkoutEntry)
        case fluidDay

        var id: String {
            switch self {
            case .editLayout: return "layout"
            case .addFood: return "food"
            case .addDrink: return "drink"
            case .addWeight: return "weight"
            case .meal(let meal): return "meal-\(meal.objectID)"
            case .drink(let drink): return "drink-\(drink.objectID)"
            case .workout(let workout): return "workout-\(workout.objectID)"
            case .fluidDay: return "fluidDay"
            }
        }
    }

    private struct LoadKey: Hashable {
        var day: Date
        var range: ChartRange
        var revision: Int
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    /// Neue Einträge auf einem vergangenen Tag: dieser Tag, aktuelle Uhrzeit.
    private var entryDate: Date {
        guard !isToday else { return Date() }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: Date())
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day
    }

    var body: some View {
        let layout = app.store.profile().dashboardLayout
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if let snapshot {
                        ForEach(layout.visibleCards) { card in
                            cardView(card, snapshot: snapshot)
                        }
                        if layout.visibleCards.isEmpty {
                            EmptyStateView(symbol: "square.dashed", title: "Aui Charte usbländet",
                                           actionTitle: "Aapasse") { sheet = .editLayout }
                        }
                    } else {
                        ProgressView().padding(40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .editLayout
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Dashboard aapasse")
                }
            }
            .refreshable { await load() }
            .task(id: LoadKey(day: day, range: range, revision: app.revision)) { await load() }
            .sheet(item: $sheet) { sheet in
                sheetView(sheet)
            }
        }
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Hüt" }
        if calendar.isDateInYesterday(day) { return "Geschter" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    // MARK: - Kopf: Tage blättern und Zeitraum der Graphen

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36)
                }
                .accessibilityLabel("Vortag")
                Spacer()
                Button {
                    day = Calendar.current.startOfDay(for: Date())
                } label: {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityHint("Zrügg zu hüt")
                Spacer()
                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 36)
                }
                .disabled(isToday)
                .accessibilityLabel("Nächschte Tag")
            }
            .contentShape(Rectangle())
            // Wischen über den Datumskopf blättert – nur hier, damit es sich nicht
            // mit dem Ziehen in den Graphen in die Quere kommt.
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                        shiftDay(value.translation.width < 0 ? 1 : -1)
                    }
            )
            Picker("Zytruum vo de Graphe", selection: $range) {
                ForEach(ChartRange.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 4)
    }

    private func shiftDay(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: delta, to: day) else { return }
        if next > Date() { return }
        withAnimation { day = Calendar.current.startOfDay(for: next) }
    }

    // MARK: - Karten

    @ViewBuilder
    private func cardView(_ card: DashboardCard, snapshot: DashboardSnapshot) -> some View {
        let profile = app.store.profile()
        switch card {
        case .energy:
            EnergyCard(snapshot: snapshot)
        case .dayLog:
            DayLogCard(snapshot: snapshot, onSelect: select, onAdd: { sheet = .addFood })
        case .fluid:
            FluidCard(
                snapshot: snapshot, range: range, quickMl: preferences.quickWaterMl,
                onQuickAdd: {
                    app.store.addWater(ml: preferences.quickWaterMl, at: entryDate)
                    app.dataDidChange()
                },
                onAdd: { sheet = .addDrink }
            )
            .onTapGesture { sheet = .fluidDay }
        case .activity:
            ActivityCard(snapshot: snapshot)
        case .weight:
            NavigationLink {
                WeightHistoryView()
            } label: {
                WeightCard(snapshot: snapshot, range: range, target: profile.targetWeight)
            }
            .buttonStyle(.plain)
        case .sleep:
            NavigationLink {
                SleepDestination.view()
            } label: {
                SleepCard(snapshot: snapshot, range: range, threshold: profile.badNightRules.absoluteThreshold)
            }
            .buttonStyle(.plain)
        case .weekAverage:
            WeekAverageCard(snapshot: snapshot)
        }
    }

    private func select(_ item: DayLogItem) {
        switch item {
        case .meal(let meal):
            sheet = .meal(meal)
        case .drink(let drink):
            sheet = .drink(drink)
        case .workout(let workout):
            if let id = workout.manualId, let entry = app.store.object(WorkoutEntry.self, id: id) {
                sheet = .workout(entry)
            }
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: Sheet) -> some View {
        switch sheet {
        case .editLayout: DashboardEditView()
        case .addFood: AddFoodView(date: entryDate)
        case .addDrink: AddDrinkView(date: entryDate)
        case .addWeight: WeightEntryView()
        case .meal(let meal): MealEditView(meal: meal)
        case .drink(let drink): AddDrinkView(existing: drink)
        case .workout(let workout): WorkoutEntryView(existing: workout)
        case .fluidDay: FluidDayView(day: day)
        }
    }

    private func load() async {
        snapshot = await DashboardLoader(app: app).load(day: day, range: range)
    }
}

/// Karten ein-/ausblenden und umsortieren (Q22).
struct DashboardEditView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var layout = DashboardLayout.standard

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.normalized.order) { card in
                        Toggle(isOn: Binding(
                            get: { layout.isVisible(card) },
                            set: { layout.setVisible(card, $0) }
                        )) {
                            Label(card.label, systemImage: card.symbolName)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .tint(card.color)
                    }
                    .onMove { layout.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Mit de drei Strichli rächts verschiebe, mit em Schalter yblände oder usblände.")
                }
                Section {
                    Button("Uf Vorgab zrügg") { layout = .standard }
                }
            }
            .themedList()
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Dashboard aapasse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        let profile = app.store.profile()
                        profile.dashboardLayout = layout
                        profile.updatedAt = Date()
                        app.dataDidChange()
                        dismiss()
                    }
                }
            }
            .onAppear { layout = app.store.profile().dashboardLayout }
        }
    }
}

/// Alle Getränke eines Tages, zum Bearbeiten und Löschen.
struct FluidDayView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var drinks: [DrinkEntry] = []
    @State private var editing: DrinkEntry?

    var body: some View {
        NavigationStack {
            List {
                if drinks.isEmpty {
                    Text("A däm Tag no nüt trunke.")
                        .foregroundStyle(Theme.textTertiary)
                }
                ForEach(drinks, id: \.objectID) { drink in
                    Button {
                        editing = drink
                    } label: {
                        HStack {
                            Image(systemName: drink.drinkType.symbolName)
                                .foregroundStyle(Theme.fluid)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drink.displayName)
                                Text(drink.timestamp?.formatted(date: .omitted, time: .shortened) ?? "")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(NumberText.volume(drink.volumeMl)).monospacedDigit()
                                if !drink.countsAsFluid {
                                    Text("zellt nid").font(.caption2).foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    offsets.map { drinks[$0] }.forEach(app.store.deleteDrink)
                    app.dataDidChange()
                    reload()
                }
            }
            .themedList()
            .navigationTitle("Trunke")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $editing, onDismiss: reload) { drink in
                AddDrinkView(existing: drink)
            }
            .task(id: app.revision) { reload() }
        }
    }

    private func reload() {
        drinks = app.store.drinks(on: day)
    }
}

/// Ziel der Schlafkarte: die letzte Nacht im Detail, sonst die Muster.
enum SleepDestination {
    static func view() -> some View {
        PatternsView()
    }
}
