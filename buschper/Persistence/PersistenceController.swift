import CoreData
import Foundation
import os

/// Der Core-Data-Stack von buschper.
///
/// Anders als Frostify gibt es nur **einen** Store: die private iCloud-Datenbank.
/// Geteilt wird nichts über CloudKit – Mahlzeiten gehen als Datei oder QR-Code weg.
///
/// Der Store liegt im **App-Group-Container**, damit das Widget dieselben Daten
/// lesen und den „+250 ml“-Knopf ausführen kann. Nur die App selbst gleicht mit
/// iCloud ab; das Widget öffnet den Store ohne CloudKit, damit nie zwei Prozesse
/// gleichzeitig spiegeln.
final class PersistenceController {
    enum Role {
        /// Die App: lokaler Store plus Abgleich mit der privaten iCloud-Datenbank.
        case app
        /// Das Widget: derselbe Store, ohne CloudKit.
        case widget
        /// Nur im Arbeitsspeicher – Vorschauen und Tests.
        case inMemory
    }

    static let shared = PersistenceController(role: .app)

    /// Muss mit Config/buschper.entitlements übereinstimmen.
    static let cloudKitContainerIdentifier = "iCloud.ch.hebera.buschper"
    static let appGroupIdentifier = "group.ch.hebera.buschper"
    static let storeFileName = "buschper.sqlite"

    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "Persistence")

    /// Das Modell wird genau einmal geladen und von allen Containern geteilt.
    /// Zwei Modell-Kopien führen zu „desired type = Meal; given type = Meal“ –
    /// dieselbe Lehre wie in Frostify.
    private static let managedObjectModel: NSManagedObjectModel = {
        let bundles = [Bundle.main, Bundle(for: PersistenceController.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "buschper", withExtension: "momd"),
               let model = NSManagedObjectModel(contentsOf: url) {
                return model
            }
        }
        if let model = NSManagedObjectModel.mergedModel(from: bundles) {
            logger.warning("Modell ueber mergedModel geladen – 'buschper.momd' wurde nicht gefunden.")
            return model
        }
        fatalError("buschper: Das Core-Data-Modell 'buschper.momd' liegt nicht im Bundle.")
    }()

    let role: Role
    let container: NSPersistentCloudKitContainer
    private(set) var loadError: Error?

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(role: Role) {
        self.role = role
        container = NSPersistentCloudKitContainer(name: "buschper", managedObjectModel: Self.managedObjectModel)

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("buschper: Der Core-Data-Stack hat keine Store-Beschreibung.")
        }

        switch role {
        case .inMemory:
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil

        case .app, .widget:
            description.url = Self.storeURL()
            // Verlauf ist Pflicht für CloudKit und nötig, damit die App Änderungen
            // des Widgets bemerkt (und umgekehrt).
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if role == .app {
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerIdentifier)
                options.databaseScope = .private
                description.cloudKitContainerOptions = options
            } else {
                description.cloudKitContainerOptions = nil
            }
        }

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { [weak self] description, error in
            if let error {
                Self.logger.error("Store \(description.url?.lastPathComponent ?? "?") nicht geladen: \(error.localizedDescription)")
                self?.loadError = error
            }
        }

        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        viewContext.transactionAuthor = role == .widget ? "widget" : "app"
        viewContext.name = "viewContext"
    }

    /// Store im App-Group-Container. Fehlt die App Group (Capability nicht
    /// eingerichtet), läuft die App mit dem Standardordner weiter – nur das Widget
    /// sieht dann keine Daten. Das steht so auch in SETUP.md.
    static func storeURL() -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return group.appendingPathComponent(storeFileName)
        }
        logger.warning("App Group \(appGroupIdentifier) nicht verfuegbar – Store im Standardordner.")
        return NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(storeFileName)
    }

    // MARK: - Speichern

    @discardableResult
    func save() -> Bool {
        guard viewContext.hasChanges else { return true }
        do {
            try viewContext.save()
            return true
        } catch {
            viewContext.rollback()
            Self.logger.error("Speichern fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    #if DEBUG
    /// Legt das CloudKit-Schema in der Development-Umgebung an (SETUP.md).
    func initializeCloudKitSchema() throws {
        try container.initializeCloudKitSchema(options: [])
    }
    #endif
}
