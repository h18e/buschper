import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Eigene Portionsgroesse eines Produkts, z. B. 1 Schiibe = 30 g.
@objc(PortionSize)
final class PortionSize: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PortionSize> {
        NSFetchRequest<PortionSize>(entityName: "PortionSize")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var grams: Double
    @NSManaged var sortIndex: Int32
    @NSManaged var product: FoodProduct?
}
