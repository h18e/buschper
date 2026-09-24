import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Manuell erfasstes Gewicht (SPEC 9).
@objc(WeightEntry)
final class WeightEntry: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WeightEntry> {
        NSFetchRequest<WeightEntry>(entityName: "WeightEntry")
    }

    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var kg: Double
    @NSManaged var createdAt: Date?
}
