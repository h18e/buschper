import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Getraenk (SPEC 7).
@objc(DrinkEntry)
final class DrinkEntry: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DrinkEntry> {
        NSFetchRequest<DrinkEntry>(entityName: "DrinkEntry")
    }

    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var drinkTypeRaw: String?
    @NSManaged var name: String?
    @NSManaged var volumeMl: Double
    @NSManaged var countsAsFluid: Bool
    @NSManaged var abvPercent: Double
    @NSManaged var nutrientsJSON: String?
    @NSManaged var presetId: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}
