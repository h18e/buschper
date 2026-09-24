import SwiftUI

/// Ziele der Schnellerfassung.
enum QuickAddDestinations {
    static func drink() -> some View { AddDrinkView() }
    static func weight() -> some View { WeightEntryView() }
    static func workout() -> some View { WorkoutEntryView() }
}
