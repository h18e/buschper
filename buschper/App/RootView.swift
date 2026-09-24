import SwiftUI

/// Die vier Tabs aus SPEC 2: Hüt · ＋ · Schlaf · Ig.
///
/// „＋“ ist kein richtiger Tab, sondern öffnet die Schnellerfassung als Blatt.
/// Danach springt die Auswahl auf den vorherigen Tab zurück.
struct RootView: View {
    let loadError: Error?

    enum TabID: Hashable {
        case today
        case add
        case sleep
        case me
    }

    @State private var selection: TabID = .today
    @State private var showsQuickAdd = false

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
            TodayPlaceholderView()
                .tag(TabID.today)
                .tabItem { Label("Hüt", systemImage: "sun.max.fill") }

            Color.clear
                .tag(TabID.add)
                .tabItem { Label("Erfasse", systemImage: "plus.circle.fill") }

            SleepPlaceholderView()
                .tag(TabID.sleep)
                .tabItem { Label("Schlaf", systemImage: "moon.zzz.fill") }

            MePlaceholderView()
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
            QuickAddPlaceholderView()
                .presentationDetents([.medium])
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
