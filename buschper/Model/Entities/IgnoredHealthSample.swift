import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Fremder Health-Wert, der nicht beruecksichtigt werden soll (SPEC 8.3).
@objc(IgnoredHealthSample)
final class IgnoredHealthSample: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<IgnoredHealthSample> {
        NSFetchRequest<IgnoredHealthSample>(entityName: "IgnoredHealthSample")
    }

    @NSManaged var id: UUID?
    @NSManaged var sampleUUID: String?
    @NSManaged var kindRaw: String?
    @NSManaged var ignoredAt: Date?
}
