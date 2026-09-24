import CoreData
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

extension SharedMeal: Identifiable {
    var id: String { "\(title)-\(entries.count)-\(total.kcal ?? 0)" }
}

extension UTType {
    /// Muss mit UTExportedTypeDeclarations in Config/Info.plist übereinstimmen.
    static let buschperMeal = UTType(exportedAs: "ch.hebera.buschper.meal")
}

/// QR-Code als Bild, erzeugt auf dem Gerät.
struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("QR-Code")
        } else {
            Text("QR-Code liess sech nid erzüge.")
                .foregroundStyle(Theme.textSecondary)
        }
    }

    static func render(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Mahlzeit teilen: Datei für WhatsApp und iMessage, QR-Code zum Abscannen (SPEC 6).
struct ShareMealView: View {
    @Environment(\.dismiss) private var dismiss
    let meal: SharedMeal

    @State private var fileURL: URL?

    private var qrLink: URL? { MealShareCodec.qrLink(for: meal) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        Text(meal.title).font(.title3.weight(.semibold))
                        Text("\(meal.entries.count) \(meal.entries.count == 1 ? "Iitrag" : "Iiträg") · \(NutrientLine.text(meal.total))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let qrLink {
                        VStack(spacing: 10) {
                            QRCodeImage(text: qrLink.absoluteString)
                                .padding(14)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .frame(maxWidth: 280)
                            Text("Mit dr Kamera oder i buschper (Ässe → QR-Code) abscanne.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Label("Die Mahlzyt isch z gross für e QR-Code. Schick se als Datei.", systemImage: "qrcode")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .card()
                    }

                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("Als Datei schicke (WhatsApp, iMessage …)", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    }

                    Text("D Empfängerin bruucht o buschper. Si cha d Mahlzyt i ihre Tag iifüege oder als Vorlag spychere. Mitgschickt wärde nume Name, Zuetate, Mängi u Nährwärt – kes Datum.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Teile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { fileURL = writeFile() }
        }
    }

    /// Die Datei landet im temporären Ordner; iOS räumt ihn selbst auf.
    private func writeFile() -> URL? {
        guard let data = try? MealShareCodec.fileData(for: meal) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(MealShareCodec.fileName(for: meal))
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Geteilte Mahlzeit übernehmen: in den eigenen Tag oder als Vorlage (Q31).
struct ImportMealView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let meal: SharedMeal

    enum Mode: String, CaseIterable, Identifiable {
        case day, template
        var id: String { rawValue }
    }

    @State private var mode: Mode = .day
    @State private var timestamp = Date()
    @State private var category: MealCategory
    @State private var done = false

    init(meal: SharedMeal) {
        self.meal = meal
        _category = State(initialValue: meal.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Array(meal.entries.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                            NutrientLine(nutrients: entry.nutrients)
                        }
                    }
                } header: {
                    Text(meal.title)
                } footer: {
                    NutrientLine(nutrients: meal.total)
                }

                Section {
                    Picker("Was mache?", selection: $mode) {
                        Text("I mym Tag iifüege").tag(Mode.day)
                        Text("Als Vorlag spychere").tag(Mode.template)
                    }
                    .pickerStyle(.segmented)
                    if mode == .day {
                        DatePicker("Zyt", selection: $timestamp)
                        Picker("Mahlzyt", selection: $category) {
                            ForEach(MealCategory.allCases) { Text($0.label).tag($0) }
                        }
                    } else {
                        Text("Wird es Rezept mit 1 Portion. Das chasch speter ände u i Portione erfasse.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .themedList()
            .navigationTitle("Mahlzyt übernäh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernäh") {
                        switch mode {
                        case .day:
                            app.store.importMeal(meal, at: timestamp, category: category)
                        case .template:
                            app.store.saveRecipe(RecipeDraft(sharedMeal: meal))
                        }
                        app.dataDidChange()
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Mahlzeit oder einzelne Einträge an einen anderen Tag kopieren (Q15).
struct CopyMealView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    let entries: [FoodEntry]
    let title: String?
    @State private var timestamp: Date
    @State private var category: MealCategory

    init(entries: [FoodEntry], title: String?, category: MealCategory, from date: Date) {
        self.entries = entries
        self.title = title
        // Vorschlag: gleiche Uhrzeit am nächsten Tag, aber nie in der Zukunft.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        _timestamp = State(initialValue: min(tomorrow, Date()))
        _category = State(initialValue: category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(entries) { entry in
                        Text(entry.displayName)
                    }
                } header: {
                    Text("\(entries.count) \(entries.count == 1 ? "Iitrag" : "Iiträg")")
                }
                Section {
                    DatePicker("Zyt", selection: $timestamp)
                    Picker("Mahlzyt", selection: $category) {
                        ForEach(MealCategory.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .themedList()
            .navigationTitle("Kopiere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Iifüege") {
                        app.store.copy(entries: entries, to: timestamp, category: category, title: title)
                        app.dataDidChange()
                        dismiss()
                    }
                    .disabled(entries.isEmpty)
                }
            }
        }
    }
}
