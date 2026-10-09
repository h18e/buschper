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

    @Test("Am Morgen gilt das Startbudget, nicht das Budget vom Vorabend")
    func newDayUsesBaseBudget() {
        var evening = WidgetSnapshot.placeholder
        evening.kcalBudget = 2800          // inkl. 900 kcal Aktivität von gestern
        evening.carbsTarget = 280
        evening.fluidGoalMl = 3100         // inkl. Training
        evening.baseBudget = 1400          // Grundumsatz 1900 − 500 Abschlag
        evening.baseFluidGoalMl = 2600
        let morning = evening.resetForNewDay(Date().addingTimeInterval(86_400))
        #expect(morning.kcalBudget == 1400)
        #expect(morning.kcalLeft == 1400)
        #expect(morning.carbsTarget == 140)
        #expect(morning.fluidGoalMl == 2600)
        #expect(morning.fluidMl == 0)
    }

    @Test("Übrige kcal und Anteil Flüssigkeit")
    func derived() {
        let snapshot = WidgetSnapshot.placeholder
        #expect(snapshot.kcalLeft == 890)
        #expect(snapshot.fluidFraction.isClose(to: 1500.0 / 2600.0, tolerance: 0.0001))
    }
}
