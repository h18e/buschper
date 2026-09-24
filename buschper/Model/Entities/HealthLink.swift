import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Verbindet einen eigenen Eintrag mit seinen Werten in Apple Health (SPEC 8.3).
@objc(HealthLink)
final class HealthLink: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<HealthLink> {
        NSFetchRequest<HealthLink>(entityName: "HealthLink")
    }

    @NSManaged var id: UUID?
    @NSManaged var localId: UUID?
    @NSManaged var localKindRaw: String?
    @NSManaged var sampleUUIDs: String?
    @NSManaged var deviceId: String?
    @NSManaged var pendingWrite: Bool
    @NSManaged var pendingDelete: Bool
    @NSManaged var updatedAt: Date?
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension HealthLink: Identifiable {}
