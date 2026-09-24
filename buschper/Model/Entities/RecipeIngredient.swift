import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Zutat mit Menge und Naehrwert-Snapshot pro 100 g/ml.
@objc(RecipeIngredient)
final class RecipeIngredient: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<RecipeIngredient> {
        NSFetchRequest<RecipeIngredient>(entityName: "RecipeIngredient")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var amountG: Double
    @NSManaged var isLiquid: Bool
    @NSManaged var nutrientsJSON: String?
    @NSManaged var sourceKindRaw: String?
    @NSManaged var sourceId: String?
    @NSManaged var sortIndex: Int32
    @NSManaged var recipe: Recipe?
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension RecipeIngredient: Identifiable {}
