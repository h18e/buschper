import SwiftUI

@main
struct BuschperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences = AppPreferences.shared

    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView(loadError: persistence.loadError)
                .environment(\.managedObjectContext, persistence.viewContext)
                .environmentObject(preferences)
                // Dunkel ist das einzige Erscheinungsbild. Zusätzlich steht
                // UIUserInterfaceStyle = Dark in der Info.plist, damit auch
                // System-Dialoge (Teilen, Scanner) dunkel erscheinen.
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
