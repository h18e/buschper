import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Eigenes Produkt oder korrigierte Kopie eines fremden (SPEC 5.5).
@objc(FoodProduct)
final class FoodProduct: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FoodProduct> {
        NSFetchRequest<FoodProduct>(entityName: "FoodProduct")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var brand: String?
    @NSManaged var barcode: String?
    @NSManaged var isLiquid: Bool
    @NSManaged var originRaw: String?
    @NSManaged var originExternalId: String?
    @NSManaged var nutrientsJSON: String?
    @NSManaged var isFavorite: Bool
    @NSManaged var useCount: Int32
    @NSManaged var lastUsedAt: Date?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var portions: NSSet?
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension FoodProduct: Identifiable {}
