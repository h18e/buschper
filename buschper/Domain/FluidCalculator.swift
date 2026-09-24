import Foundation

/// Flüssigkeitsziel (SPEC 4.6).
///
/// `35 ml × kg + 500 ml pro Trainingsstunde`, auf 50 ml gerundet. Ein von Hand
/// gesetzter Wert übersteuert die Formel.
enum FluidCalculator {
    static let mlPerKg = 35.0
    static let mlPerTrainingHour = 500.0

    static func goalMl(weightKg: Double, trainingMinutes: Double, overrideMl: Double?) -> Double {
        if let overrideMl, overrideMl > 0 {
            return overrideMl
        }
        let raw = max(0, weightKg) * mlPerKg + max(0, trainingMinutes) / 60 * mlPerTrainingHour
        return (raw / 50).rounded() * 50
    }
}
