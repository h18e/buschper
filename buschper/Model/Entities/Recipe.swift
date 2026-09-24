import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Rezept mit Zutaten und Portionen (SPEC 5.7).
@objc(Recipe)
final class Recipe: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Recipe> {
        NSFetchRequest<Recipe>(entityName: "Recipe")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var servings: Double
    @NSManaged var note: String?
    @NSManaged var isFavorite: Bool
    @NSManaged var useCount: Int32
    @NSManaged var lastUsedAt: Date?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var ingredients: NSSet?
}
