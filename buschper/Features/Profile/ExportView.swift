import CoreData
import SwiftUI

/// Alle Daten als CSV für Excel (SPEC 16).
struct ExportView: View {
    @Environment(AppEnvironment.self) private var app

    @State private var range: ExportService.Range = .all
    @State private var files: [URL] = []
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section {
                Picker("Zytruum", selection: $range) {
                    ForEach(ExportService.Range.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: range) { _, _ in files = [] }

                Button {
                    Task { await export() }
                } label: {
                    if working {
                        HStack { ProgressView(); Text("Exportiere …") }
                    } else {
                        Text("Dateie erstelle")
                    }
                }
                .disabled(working)
            } footer: {
                Text("Füf CSV-Dateie: Mahlzyte, Getränk, Trainings, Gwicht u Schlaf. Semikolon als Trennzeiche, Excel list se diräkt.")
            }

            if !files.isEmpty {
                Section {
                    ForEach(files, id: \.self) { file in
                        Label(file.lastPathComponent, systemImage: "doc.text")
                    }
                    ShareLink(items: files) {
                        Label("Teile oder i Dateie spychere", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if let errorText {
                Section {
                    Text(errorText).foregroundStyle(Theme.bad)
                }
            }
        }
        .themedList()
        .navigationTitle("Date exportiere")
    }

    private func export() async {
        working = true
        errorText = nil
        defer { working = false }
        do {
            files = try await ExportService(store: app.store, dayData: app.dayData).export(range: range)
        } catch {
            errorText = "Export fählgschlage: \(error.localizedDescription)"
        }
    }
}
