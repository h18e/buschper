import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Eigene Getraenkevorlage, z. B. Cappuccino 2 dl.
@objc(DrinkPreset)
final class DrinkPreset: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DrinkPreset> {
        NSFetchRequest<DrinkPreset>(entityName: "DrinkPreset")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var drinkTypeRaw: String?
    @NSManaged var volumeMl: Double
    @NSManaged var abvPercent: Double
    @NSManaged var nutrientsJSON: String?
    @NSManaged var sortIndex: Int32
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension DrinkPreset: Identifiable {}
