import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Gemerktes fremdes Produkt (BLV oder Open Food Facts) fuer Favoriten und Zletscht bruucht.
@objc(ExternalFoodRef)
final class ExternalFoodRef: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ExternalFoodRef> {
        NSFetchRequest<ExternalFoodRef>(entityName: "ExternalFoodRef")
    }

    @NSManaged var id: UUID?
    @NSManaged var sourceRaw: String?
    @NSManaged var externalId: String?
    @NSManaged var name: String?
    @NSManaged var brand: String?
    @NSManaged var isLiquid: Bool
    @NSManaged var nutrientsJSON: String?
    @NSManaged var isFavorite: Bool
    @NSManaged var useCount: Int32
    @NSManaged var lastUsedAt: Date?
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension ExternalFoodRef: Identifiable {}
