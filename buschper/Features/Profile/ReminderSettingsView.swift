import CoreData
import SwiftUI

/// Erinnerungen ein-/ausschalten (SPEC 15).
struct ReminderSettingsView: View {
    @Environment(AppEnvironment.self) private var app
    @EnvironmentObject private var preferences: AppPreferences
    @State private var denied = false

    var body: some View {
        Form {
            Section {
                Toggle("Trink-Erinnerig", isOn: Binding(
                    get: { preferences.waterReminderEnabled },
                    set: { enable($0) { preferences.waterReminderEnabled = $0 } }
                ))
                if preferences.waterReminderEnabled {
                    Stepper(value: Binding(get: { preferences.waterReminderStartHour }, set: { preferences.waterReminderStartHour = $0 }),
                            in: 5...20) {
                        LabeledValueRow(label: "Vo") { Text("\(preferences.waterReminderStartHour):00").monospacedDigit() }
                    }
                    Stepper(value: Binding(get: { preferences.waterReminderEndHour }, set: { preferences.waterReminderEndHour = $0 }),
                            in: 8...23) {
                        LabeledValueRow(label: "Bis") { Text("\(preferences.waterReminderEndHour):00").monospacedDigit() }
                    }
                    Stepper(value: Binding(get: { preferences.waterReminderIntervalHours }, set: { preferences.waterReminderIntervalHours = $0 }),
                            in: 1...6) {
                        LabeledValueRow(label: "Alli") { Text("\(preferences.waterReminderIntervalHours) h").monospacedDigit() }
                    }
                }
            } header: {
                Text("Trinke")
            } footer: {
                Text("Hüt nume, solang ds Tagesziel no nid erreicht isch.")
            }

            Section {
                Toggle("Morge-Iischätzig", isOn: Binding(
                    get: { preferences.morningCheckInEnabled },
                    set: { enable($0) { preferences.morningCheckInEnabled = $0 } }
                ))
                if preferences.morningCheckInEnabled {
                    DatePicker(
                        "Zyt",
                        selection: Binding(
                            get: {
                                Calendar.current.date(bySettingHour: preferences.morningCheckInHour,
                                                      minute: preferences.morningCheckInMinute, second: 0, of: Date()) ?? Date()
                            },
                            set: { date in
                                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                                preferences.morningCheckInHour = parts.hour ?? 7
                                preferences.morningCheckInMinute = parts.minute ?? 30
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Schlaf")
            } footer: {
                Text("Fragt am Morge, wie du gschlafe hesch. Die Iischätzig macht d Schlafuswärtig vil gnauer.")
            }

            if denied {
                Section {
                    Text("Mitteilige sy für buschper nid erloubt. Das chasch i de iOS-Istellige → Mitteilige → buschper ändere.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
            }

            Section {
                NumberField(
                    title: "Schnälltaste Wasser",
                    value: Binding(get: { preferences.quickWaterMl }, set: { preferences.quickWaterMl = $0 }),
                    unit: "ml",
                    fractionDigits: 0
                )
            } footer: {
                Text("Gilt für ds Dashboard u ds Widget.")
            }
        }
        .themedList()
        .navigationTitle("Erinnerige")
        .onDisappear {
            Task {
                await app.notifications.refresh()
                await app.widget.refresh()
            }
        }
    }

    /// Beim Einschalten zuerst die Erlaubnis holen.
    private func enable(_ on: Bool, apply: @escaping (Bool) -> Void) {
        guard on else {
            apply(false)
            Task { await app.notifications.refresh() }
            return
        }
        Task {
            let granted = await app.notifications.requestPermission()
            denied = !granted
            apply(granted)
            await app.notifications.refresh()
        }
    }
}
