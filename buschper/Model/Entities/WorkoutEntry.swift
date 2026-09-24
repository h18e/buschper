import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Manuelles Training (SPEC 10.2).
@objc(WorkoutEntry)
final class WorkoutEntry: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WorkoutEntry> {
        NSFetchRequest<WorkoutEntry>(entityName: "WorkoutEntry")
    }

    @NSManaged var id: UUID?
    @NSManaged var start: Date?
    @NSManaged var durationMinutes: Double
    @NSManaged var sportTypeRaw: String?
    @NSManaged var intensityRaw: String?
    @NSManaged var kcal: Double
    @NSManaged var kcalIsManual: Bool
    @NSManaged var note: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

/// Fuer ForEach und sheet(item:). Die Kennung ist das eigene `id`-Feld (UUID).
extension WorkoutEntry: Identifiable {}
