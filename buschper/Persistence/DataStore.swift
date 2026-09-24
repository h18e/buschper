import CoreData
import Foundation
import os

/// Zentraler Zugang zu den Daten. Kein Feature-Code fasst einen
/// `NSManagedObjectContext` direkt an – mit Ausnahme von `@FetchRequest` in
/// Listen, damit diese sich bei eintreffenden iCloud-Änderungen selbst erneuern.
///
/// Die Funktionen pro Bereich stehen in eigenen Dateien (`DataStore+Food.swift` …).
@MainActor
final class DataStore {
    let persistence: PersistenceController
    let preferences: AppPreferences

    static let logger = Logger(subsystem: "ch.hebera.buschper", category: "DataStore")

    var context: NSManagedObjectContext { persistence.viewContext }

    init(persistence: PersistenceController, preferences: AppPreferences) {
        self.persistence = persistence
        self.preferences = preferences
    }

    @discardableResult
    func save() -> Bool {
        persistence.save()
    }

    func fetch<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = [],
        limit: Int? = nil
    ) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        request.sortDescriptors = sort
        if let limit { request.fetchLimit = limit }
        do {
            return try context.fetch(request)
        } catch {
            Self.logger.error("Laden von \(String(describing: type)) fehlgeschlagen: \(error.localizedDescription)")
            return []
        }
    }

    func object<T: NSManagedObject>(_ type: T.Type, id: UUID) -> T? {
        fetch(type, predicate: NSPredicate(format: "id == %@", id as CVarArg), limit: 1).first
    }

    /// Prädikat für Einträge mit Zeitstempel innerhalb eines Tages.
    static func dayPredicate(_ key: String, day: Date, calendar: Calendar = .current) -> NSPredicate {
        let start = calendar.startOfDay(for: day)
        let end = DayMath.nextDay(of: start, calendar: calendar)
        return NSPredicate(format: "%K >= %@ AND %K < %@", key, start as NSDate, key, end as NSDate)
    }

    static func rangePredicate(_ key: String, from start: Date, to end: Date) -> NSPredicate {
        NSPredicate(format: "%K >= %@ AND %K < %@", key, start as NSDate, key, end as NSDate)
    }

    // MARK: - Profil

    /// Das eine Profil. Gibt es nach einem iCloud-Abgleich zwei (auf zwei Geräten
    /// gleichzeitig eingerichtet), gilt das eingerichtete, älteste – eindeutig und
    /// auf allen Geräten gleich.
    func profile() -> Profile {
        let all = fetch(Profile.self)
        if let existing = all.sorted(by: Self.profileOrder).first {
            return existing
        }
        let profile = Profile(context: context)
        profile.id = UUID()
        profile.createdAt = Date()
        profile.updatedAt = Date()
        profile.dashboardLayout = .standard
        profile.factorThresholds = .standard
        profile.badNightRules = .standard
        save()
        return profile
    }

    private static func profileOrder(_ lhs: Profile, _ rhs: Profile) -> Bool {
        if lhs.onboardingCompleted != rhs.onboardingCompleted {
            return lhs.onboardingCompleted
        }
        return (lhs.createdAt ?? .distantFuture) < (rhs.createdAt ?? .distantFuture)
    }

    func touchProfile() {
        profile().updatedAt = Date()
        save()
    }
}

// MARK: - Apple-Health-Verknüpfungen

extension DataStore {
    /// Merkt vor, dass ein eigener Eintrag nach Health geschrieben (oder dort
    /// ersetzt) werden soll – nur auf diesem Gerät (SPEC 8.3).
    func markForHealthWrite(localId: UUID, kind: HealthSampleKind) {
        let link = healthLink(localId: localId) ?? {
            let link = HealthLink(context: context)
            link.id = UUID()
            link.localId = localId
            return link
        }()
        link.localKindRaw = kind.rawValue
        link.deviceId = preferences.deviceId
        link.pendingWrite = true
        link.pendingDelete = false
        link.updatedAt = Date()
    }

    /// Merkt vor, dass die Health-Werte eines gelöschten Eintrags entfernt werden.
    /// Gab es nie eine Verknüpfung (Eintrag stammt von einem anderen Gerät, das
    /// noch nicht geschrieben hat), wird trotzdem gelöscht – das schadet nicht.
    func markForHealthDelete(localId: UUID, kind: HealthSampleKind) {
        let link = healthLink(localId: localId) ?? {
            let link = HealthLink(context: context)
            link.id = UUID()
            link.localId = localId
            return link
        }()
        link.localKindRaw = kind.rawValue
        link.deviceId = preferences.deviceId
        link.pendingWrite = false
        link.pendingDelete = true
        link.updatedAt = Date()
    }

    func healthLink(localId: UUID) -> HealthLink? {
        fetch(HealthLink.self, predicate: NSPredicate(format: "localId == %@", localId as CVarArg), limit: 1).first
    }

    /// Offene Aufträge dieses Geräts.
    func pendingHealthLinks() -> [HealthLink] {
        fetch(
            HealthLink.self,
            predicate: NSPredicate(
                format: "deviceId == %@ AND (pendingWrite == YES OR pendingDelete == YES)",
                preferences.deviceId
            ),
            sort: [NSSortDescriptor(key: "updatedAt", ascending: true)]
        )
    }

    // MARK: - Ignorierte fremde Werte

    func ignoredSampleIDs(kind: HealthSampleKind) -> Set<String> {
        let ignored = fetch(IgnoredHealthSample.self, predicate: NSPredicate(format: "kindRaw == %@", kind.rawValue))
        return Set(ignored.compactMap(\.sampleUUID))
    }

    func setIgnored(_ ignored: Bool, sampleUUID: UUID, kind: HealthSampleKind) {
        let existing = fetch(
            IgnoredHealthSample.self,
            predicate: NSPredicate(format: "sampleUUID == %@", sampleUUID.uuidString)
        )
        if ignored {
            guard existing.isEmpty else { return }
            let entry = IgnoredHealthSample(context: context)
            entry.id = UUID()
            entry.sampleUUID = sampleUUID.uuidString
            entry.kindRaw = kind.rawValue
            entry.ignoredAt = Date()
        } else {
            existing.forEach(context.delete)
        }
        save()
    }
}
