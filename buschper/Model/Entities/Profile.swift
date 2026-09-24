import CoreData
import Foundation

// Erzeugt von tools/generate_model.py – nicht von Hand aendern.
// Bequeme Zugriffe stehen in Model/EntityExtensions/.

/// Profil und Ziele. Es gibt genau eines (SPEC 4).
@objc(Profile)
final class Profile: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Profile> {
        NSFetchRequest<Profile>(entityName: "Profile")
    }

    @NSManaged var id: UUID?
    @NSManaged var sexRaw: String?
    @NSManaged var birthDate: Date?
    @NSManaged var heightCm: Double
    @NSManaged var goalRaw: String?
    @NSManaged var offsetLose: Double
    @NSManaged var offsetMaintain: Double
    @NSManaged var offsetGain: Double
    @NSManaged var carbsPercent: Double
    @NSManaged var proteinPercent: Double
    @NSManaged var fatPercent: Double
    @NSManaged var fiberMinG: Double
    @NSManaged var activityProfileRaw: String?
    @NSManaged var sleepGoalMinutes: Int32
    @NSManaged var stepGoal: Int32
    @NSManaged var waterGoalOverrideMl: Double
    @NSManaged var targetWeightKg: Double
    @NSManaged var fallbackWeightKg: Double
    @NSManaged var dashboardLayoutJSON: String?
    @NSManaged var factorThresholdsJSON: String?
    @NSManaged var badNightRulesJSON: String?
    @NSManaged var onboardingCompleted: Bool
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}
