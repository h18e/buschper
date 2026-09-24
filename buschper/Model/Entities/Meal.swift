import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Mahlzeit: Zeitpunkt, Kategorie und Eintraege (SPEC 5.2).
@objc(Meal)
final class Meal: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Meal> {
        NSFetchRequest<Meal>(entityName: "Meal")
    }

    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var categoryRaw: String?
    @NSManaged var title: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var entries: NSSet?
}
