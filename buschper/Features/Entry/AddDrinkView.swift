import CoreData
import SwiftUI

/// „Trinke“: Getränk erfassen oder bearbeiten (SPEC 7).
struct AddDrinkView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let existing: DrinkEntry?

    @State private var draft: DrinkDraft
    @State private var presets: [DrinkPreset] = []
    @State private var showsDetails = false
    @State private var savedPreset = false
    @State private var confirmsDelete = false

    init(existing: DrinkEntry? = nil, date: Date = Date()) {
        self.existing = existing
        _draft = State(initialValue: existing.map(DrinkDraft.init(entry:)) ?? DrinkDraft(type: .water, at: date))
    }

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil && !presets.isEmpty {
                    Section("Vorlage") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets) { preset in
                                    Button {
                                        draft = DrinkDraft(preset: preset, at: draft.timestamp)
                                    } label: {
                                        Label("\(preset.name ?? "") · \(NumberText.volume(preset.volumeMl))",
                                              systemImage: preset.drinkType.symbolName)
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Theme.fluid)
                                    .contextMenu {
                                        Button("Vorlag lösche", role: .destructive) {
                                            app.store.deletePreset(preset)
                                            app.dataDidChange()
                                            presets = app.store.drinkPresets()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(DrinkType.allCases) { type in
                            typeButton(type)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach([150.0, 250, 330, 500], id: \.self) { ml in
                            Button(NumberText.volume(ml)) { draft.volumeMl = ml }
                                .buttonStyle(.bordered)
                                .tint(draft.volumeMl == ml ? Theme.fluid : Theme.textSecondary)
                        }
                    }
                    NumberField(title: "Mängi", value: $draft.volumeMl, unit: "ml", fractionDigits: 0)
                    if draft.drinkType.isAlcoholic || draft.abvPercent > 0 {
                        NumberField(title: "Alkohol", value: $draft.abvPercent, unit: "Vol-%")
                    }
                    DatePicker("Zyt", selection: $draft.timestamp)
                    if draft.drinkType == .custom || !draft.name.isEmpty {
                        TextField("Name, z. B. Cappuccino", text: $draft.name)
                    }
                } footer: {
                    Text(summary)
                }

                Section {
                    DisclosureGroup("Nährwärt u Details", isExpanded: $showsDetails) {
                        Toggle("Zellt zur Flüssigkeit", isOn: $draft.countsAsFluid)
                        TextField("Name", text: $draft.name)
                        NutrientInputs(nutrients: $draft.per100ml, isLiquid: true)
                        Text("Wärt pro 100 ml, ohni Alkohol – dä wird us de Vol-% berächnet. D Vorgabe sy Richtwärt.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                if existing == nil {
                    Section {
                        Button(savedPreset ? "Als Vorlag gspycheret ✓" : "Als Vorlag spychere") {
                            app.store.savePreset(from: draft)
                            app.dataDidChange()
                            presets = app.store.drinkPresets()
                            savedPreset = true
                        }
                        .disabled(savedPreset)
                    }
                } else {
                    Section {
                        Button("Lösche", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .themedList()
            .navigationTitle(existing == nil ? "Trinke" : "Getränk bearbeite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichere") {
                        app.store.saveDrink(draft, editing: existing)
                        app.dataDidChange()
                        dismiss()
                    }
                    .disabled(draft.volumeMl <= 0)
                }
            }
            .confirmationDialog("Getränk lösche?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Lösche", role: .destructive) {
                    if let existing { app.store.deleteDrink(existing) }
                    app.dataDidChange()
                    dismiss()
                }
            }
            .task { presets = app.store.drinkPresets() }
        }
    }

    private var summary: String {
        let total = draft.total
        var parts: [String] = []
        parts.append(draft.countsAsFluid ? "\(NumberText.volume(draft.volumeMl)) Flüssigkeit" : "Zellt nid zur Flüssigkeit")
        if let kcal = total.kcal, kcal > 0 { parts.append("\(NumberText.kcal(kcal)) kcal") }
        if let alcohol = total.alcohol, alcohol > 0 { parts.append("\(NumberText.oneDecimal(alcohol)) g Alkohol") }
        if let caffeine = total.caffeine, caffeine > 0 { parts.append("\(NumberText.kcal(caffeine)) mg Koffein") }
        return parts.joined(separator: " · ")
    }

    private func typeButton(_ type: DrinkType) -> some View {
        let selected = draft.drinkType == type
        return Button {
            let keepVolume = draft.volumeMl
            draft.apply(type: type)
            // Beim Wechsel zwischen ähnlichen Getränken bleibt die Menge, wenn sie
            // schon angepasst war.
            if existing != nil { draft.volumeMl = keepVolume }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.symbolName)
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.background : Theme.fluid)
                    .frame(width: 44, height: 44)
                    .background(selected ? Theme.fluid : Theme.fluid.opacity(0.14), in: Circle())
                Text(type.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }
}
