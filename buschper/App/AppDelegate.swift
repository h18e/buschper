import UIKit
import UserNotifications

/// Wird per `@UIApplicationDelegateAdaptor` an die SwiftUI-App gehängt.
///
/// Meldet die App für stille Mitteilungen an, damit CloudKit Änderungen anderer
/// Geräte (z. B. iPad) sofort meldet, und zeigt Erinnerungen auch bei offener App.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Der NSPersistentCloudKitContainer verarbeitet die Mitteilung selbst.
        completionHandler(.newData)
    }
}

/// Zeigt Erinnerungen auch an, wenn die App gerade offen ist.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
