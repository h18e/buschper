import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Geloggter Eintrag mit festem Naehrwert-Snapshot (SPEC 5.9).
@objc(FoodEntry)
final class FoodEntry: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FoodEntry> {
        NSFetchRequest<FoodEntry>(entityName: "FoodEntry")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var amount: Double
    @NSManaged var unitLabel: String?
    @NSManaged var grams: Double
    @NSManaged var isLiquid: Bool
    @NSManaged var nutrientsJSON: String?
    @NSManaged var kindRaw: String?
    @NSManaged var sourceId: String?
    @NSManaged var servings: Double
    @NSManaged var sortIndex: Int32
    @NSManaged var meal: Meal?
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension FoodEntry: Identifiable {}
