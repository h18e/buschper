import CoreData
import SwiftUI

/// „Gwicht“: manuell erfassen oder bearbeiten (SPEC 9).
struct WeightEntryView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let existing: WeightEntry?

    @State private var kg: Double
    @State private var date: Date
    @State private var confirmsDelete = false
    @State private var loadedReference = false

    init(existing: WeightEntry? = nil) {
        self.existing = existing
        _kg = State(initialValue: existing?.kg ?? 0)
        _date = State(initialValue: existing?.timestamp ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField(title: "Gwicht", value: $kg, unit: "kg")
                    HStack {
                        ForEach([-0.5, -0.1, 0.1, 0.5], id: \.self) { step in
                            Button(step > 0 ? "+\(NumberText.oneDecimal(step))" : NumberText.oneDecimal(step)) {
                                kg = max(0, ((kg + step) * 10).rounded() / 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.weight)
                        }
                    }
                    DatePicker("Zyt", selection: $date, in: ...Date())
                } footer: {
                    Text("Wird o i Apple Health gspycheret.")
                }
                if existing != nil {
                    Section {
                        Button("Lösche", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .themedList()
            .navigationTitle(existing == nil ? "Gwicht" : "Gwicht bearbeite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") {
                        app.store.saveWeight(kg: kg, at: date, editing: existing)
                        app.dataDidChange()
                        dismiss()
                    }
                    .disabled(kg < 20 || kg > 400)
                }
            }
            .confirmationDialog("Gwicht lösche?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Lösche", role: .destructive) {
                    if let existing { app.store.deleteWeight(existing) }
                    app.dataDidChange()
                    dismiss()
                }
            }
            .task {
                // Neuer Eintrag: mit dem letzten bekannten Gewicht vorbelegen.
                guard existing == nil, !loadedReference else { return }
                loadedReference = true
                let reference = await app.dayData.referenceWeight(for: Date())
                if kg == 0 { kg = (reference.kg * 10).rounded() / 10 }
            }
        }
    }
}

/// Alle Gewichtswerte: eigene bearbeiten, fremde ignorieren (SPEC 8.3, 9).
struct WeightHistoryView: View {
    @Environment(AppEnvironment.self) private var app

    @State private var points: [WeightPoint] = []
    @State private var ignoredPoints: [HealthWeight] = []
    @State private var editing: WeightEntry?
    @State private var adding = false
    @State private var showsIgnored = false

    var body: some View {
        List {
            Section {
                if points.isEmpty {
                    Text("I de letschte 90 Täg kener Wärt.")
                        .foregroundStyle(Theme.textTertiary)
                }
                ForEach(Array(points.reversed())) { point in
                    row(point)
                }
            } footer: {
                Text("Wärt vo dr Waag oder angere Apps chasch nid ändere, aber ignoriere – nach links wüsche.")
            }

            if !ignoredPoints.isEmpty {
                Section {
                    DisclosureGroup("Ignorierti Wärt (\(ignoredPoints.count))", isExpanded: $showsIgnored) {
                        ForEach(ignoredPoints) { weight in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(NumberText.oneDecimal(weight.kg)) kg").strikethrough()
                                    Text("\(weight.date.formatted(date: .abbreviated, time: .shortened)) · \(weight.sourceName)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                Button("Wieder bruuche") {
                                    app.store.setIgnored(false, sampleUUID: weight.id, kind: .weight)
                                    app.dataDidChange()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .themedList()
        .navigationTitle("Gwicht")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editing) { entry in
            WeightEntryView(existing: entry)
        }
        .sheet(isPresented: $adding) {
            WeightEntryView()
        }
        .task(id: app.revision) { await load() }
    }

    @ViewBuilder
    private func row(_ point: WeightPoint) -> some View {
        let content = HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(NumberText.oneDecimal(point.kg)) kg")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(point.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            switch point.origin {
            case .manual:
                BadgeView(text: "Vo Hand", color: Theme.weight)
            case .health(_, let source):
                Text(source)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }

        switch point.origin {
        case .manual(let id):
            Button {
                editing = app.store.object(WeightEntry.self, id: id)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .swipeActions {
                Button("Lösche", role: .destructive) {
                    if let entry = app.store.object(WeightEntry.self, id: id) {
                        app.store.deleteWeight(entry)
                        app.dataDidChange()
                    }
                }
            }
        case .health(let id, _):
            content
                .swipeActions {
                    Button("Ignoriere") {
                        app.store.setIgnored(true, sampleUUID: id, kind: .weight)
                        app.dataDidChange()
                    }
                    .tint(Theme.warning)
                }
        }
    }

    private func load() async {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -90, to: end) ?? end
        points = await app.dayData.weights(from: start, to: end)
        let ignored = app.store.ignoredSampleIDs(kind: .weight)
        if ignored.isEmpty {
            ignoredPoints = []
        } else {
            ignoredPoints = await app.health.foreignWeights(from: start, to: end)
                .filter { ignored.contains($0.id.uuidString) }
        }
    }
}
