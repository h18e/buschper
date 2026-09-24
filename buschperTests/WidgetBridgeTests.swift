import Foundation
import Testing
@testable import buschper

@Suite("Widget")
struct WidgetBridgeTests {
    @Test("Ein neuer Tag beginnt bei 0, Ziele bleiben")
    func newDay() {
        let yesterday = WidgetSnapshot.placeholder
        let today = yesterday.resetForNewDay(Date().addingTimeInterval(86_400))
        #expect(today.kcalEaten == 0)
        #expect(today.fluidMl == 0)
        #expect(today.kcalBudget == yesterday.kcalBudget)
        #expect(today.fluidGoalMl == yesterday.fluidGoalMl)
    }

    @Test("Übrige kcal und Anteil Flüssigkeit")
    func derived() {
        let snapshot = WidgetSnapshot.placeholder
        #expect(snapshot.kcalLeft == 890)
        #expect(snapshot.fluidFraction.isClose(to: 1500.0 / 2600.0, tolerance: 0.0001))
    }
}
