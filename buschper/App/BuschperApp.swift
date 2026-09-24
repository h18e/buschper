import SwiftUI

@main
struct BuschperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var environment = AppEnvironment.live
    @StateObject private var preferences = AppPreferences.shared

    var body: some Scene {
        WindowGroup {
            RootView(loadError: environment.persistence.loadError)
                .environment(environment)
                .environment(\.managedObjectContext, environment.persistence.viewContext)
                .environmentObject(preferences)
                // Dunkel ist das einzige Erscheinungsbild. Zusätzlich steht
                // UIUserInterfaceStyle = Dark in der Info.plist, damit auch
                // System-Dialoge (Teilen, Scanner) dunkel erscheinen.
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await environment.appBecameActive() }
            }
        }
    }
}
