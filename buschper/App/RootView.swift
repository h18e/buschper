import CoreData
import SwiftUI

/// Die vier Tabs aus SPEC 2: Hüt · ＋ · Schlaf · Ig.
///
/// „＋“ ist kein richtiger Tab, sondern öffnet die Schnellerfassung als Blatt.
/// Danach springt die Auswahl auf den vorherigen Tab zurück.
struct RootView: View {
    let loadError: Error?

    @Environment(AppEnvironment.self) private var app

    enum TabID: Hashable {
        case today
        case add
        case sleep
        case me
    }

    @State private var selection: TabID = .today
    @State private var showsQuickAdd = false
    @State private var showsOnboarding = false
    @State private var importing: SharedMeal?
    @State private var importError: String?

    var body: some View {
        Group {
            if let loadError {
                StoreErrorView(error: loadError)
            } else {
                tabs
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(TabID.today)
                .tabItem { Label("Hüt", systemImage: "sun.max.fill") }

            Color.clear
                .tag(TabID.add)
                .tabItem { Label("Erfasse", systemImage: "plus.circle.fill") }

            SleepView()
                .tag(TabID.sleep)
                .tabItem { Label("Schlaf", systemImage: "moon.zzz.fill") }

            MeView()
                .tag(TabID.me)
                .tabItem { Label("Ig", systemImage: "person.crop.circle.fill") }
        }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .add {
                selection = oldValue
                showsQuickAdd = true
            }
        }
        .sheet(isPresented: $showsQuickAdd) {
            QuickAddSheet()
                .presentationDetents([.height(240), .medium])
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(profile: app.store.profile()) {
                showsOnboarding = false
            }
        }
        .onOpenURL(perform: handleOpen)
        .onReceive(NotificationCenter.default.publisher(for: .buschperOpenSleep)) { _ in
            selection = .sleep
        }
        .sheet(item: $importing) { meal in
            ImportMealView(meal: meal)
        }
        .alert("Mahlzyt übernäh", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .task(id: app.revision) {
            if !app.store.profile().onboardingCompleted {
                showsOnboarding = true
            }
        }
    }
}

extension RootView {
    /// Geteilte Mahlzeit: `.buschper`-Datei aus WhatsApp/iMessage oder
    /// `buschper://import?m=…` aus einem QR-Code (SPEC 6).
    func handleOpen(_ url: URL) {
        do {
            if url.isFileURL {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                importing = try MealShareCodec.decode(fileData: data)
            } else {
                importing = try MealShareCodec.decode(url: url)
            }
        } catch MealShareCodec.DecodeError.unsupportedVersion {
            importError = "Die Mahlzyt chunnt vore nöiere buschper-Version. Bitte buschper aktualisiere."
        } catch {
            importError = "Die Datei oder dä Link cha buschper nid läse."
        }
    }
}

/// Wenn die Datenbank nicht geladen werden kann, ist das ein klar sichtbarer Zustand.
private struct StoreErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 8) {
            EmptyStateView(
                symbol: "externaldrive.badge.xmark",
                title: "Date nid verfüegbar",
                message: "D lokali Datebank het sech nid la uftue."
            )
            Text(error.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}
