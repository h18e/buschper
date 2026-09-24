import CoreData
import SwiftUI

/// „Training“: manuelles Training erfassen oder bearbeiten (SPEC 10.2).
struct WorkoutEntryView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let existing: WorkoutEntry?

    @State private var draft: WorkoutDraft
    @State private var weightKg: Double = 75
    @State private var confirmsDelete = false

    init(existing: WorkoutEntry? = nil) {
        self.existing = existing
        _draft = State(initialValue: existing.map(WorkoutDraft.init(entry:)) ?? WorkoutDraft())
    }

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(SportType.allCases) { sport in
                            sportButton(sport)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    DatePicker("Start", selection: $draft.start, in: ...Date())
                    Stepper(value: $draft.durationMinutes, in: 5...600, step: 5) {
                        LabeledValueRow(label: "Duur") {
                            Text(OnboardingView.hoursText(Int(draft.durationMinutes)))
                                .monospacedDigit()
                        }
                    }
                    Picker("Intensität", selection: $draft.intensity) {
                        ForEach(WorkoutIntensity.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Kalorie vo Hand", isOn: $draft.kcalIsManual)
                    if draft.kcalIsManual {
                        NumberField(title: "Energie", value: $draft.kcal, unit: "kcal", fractionDigits: 0)
                    } else {
                        LabeledValueRow(label: "Gschätzt") {
                            Text("\(NumberText.kcal(draft.estimatedKcal(weightKg: weightKg))) kcal")
                                .monospacedDigit()
                                .foregroundStyle(Theme.activity)
                        }
                    }
                } footer: {
                    Text("Schätzig: MET-Wärt × \(NumberText.oneDecimal(weightKg)) kg × Stunde. Das Training wird i Apple Health gspycheret u d Kalorie zelle denn als Aktivkalorie. Treisch derbi d Uhr, het si meist scho es Training – denn lieber dert erfasse, süsch zellt's doppelt.")
                }

                Section {
                    TextField("Notiz (fakultativ)", text: $draft.note)
                }

                if existing != nil {
                    Section {
                        Button("Lösche", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .themedList()
            .navigationTitle(existing == nil ? "Training" : "Training bearbeite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") {
                        app.store.saveWorkout(draft, weightKg: weightKg, editing: existing)
                        app.dataDidChange()
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Training lösche?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Lösche", role: .destructive) {
                    if let existing { app.store.deleteWorkout(existing) }
                    app.dataDidChange()
                    dismiss()
                }
            }
            .onChange(of: draft.kcalIsManual) { _, manual in
                if manual && draft.kcal == 0 {
                    draft.kcal = draft.estimatedKcal(weightKg: weightKg)
                }
            }
            .task {
                weightKg = await app.dayData.referenceWeight(for: draft.start).kg
            }
        }
    }

    private func sportButton(_ sport: SportType) -> some View {
        let selected = draft.sport == sport
        return Button {
            draft.sport = sport
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sport.symbolName)
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.background : Theme.activity)
                    .frame(width: 44, height: 44)
                    .background(selected ? Theme.activity : Theme.activity.opacity(0.14), in: Circle())
                Text(sport.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }
}
