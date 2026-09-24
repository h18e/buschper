import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Ausgewertete Nacht mit Vortagskennzahlen und Faktoren (SPEC 12.2).
@objc(NightRecord)
final class NightRecord: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<NightRecord> {
        NSFetchRequest<NightRecord>(entityName: "NightRecord")
    }

    @NSManaged var id: UUID?
    @NSManaged var nightDate: Date?
    @NSManaged var score: Double
    @NSManaged var componentsJSON: String?
    @NSManaged var asleepMinutes: Double
    @NSManaged var deepMinutes: Double
    @NSManaged var remMinutes: Double
    @NSManaged var coreMinutes: Double
    @NSManaged var awakeMinutes: Double
    @NSManaged var hasStages: Bool
    @NSManaged var sleepOnset: Date?
    @NSManaged var wakeTime: Date?
    @NSManaged var rating: Int16
    @NSManaged var isBad: Bool
    @NSManaged var badReasonsJSON: String?
    @NSManaged var factorsJSON: String?
    @NSManaged var dayMetricsJSON: String?
    @NSManaged var note: String?
    @NSManaged var tagsJSON: String?
    @NSManaged var excluded: Bool
    @NSManaged var computedAt: Date?
}
