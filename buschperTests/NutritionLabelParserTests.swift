import CoreGraphics
import Foundation
import Testing
@testable import buschper

/// Fotografierte Nährwerttabellen auslesen – typische Schweizer Packungen.
struct NutritionLabelParserTests {
    @Test("Dreisprachige Tabelle, erste Spalte pro 100 g")
    func trilingual() {
        let result = NutritionLabelParser.parse(rows: [
            "Nährwerte / Valeurs nutritives / Valori nutritivi   pro 100 g   pro Portion 30 g",
            "Energie / Énergie / Energia   1'674 kJ (400 kcal)   502 kJ (120 kcal)",
            "Fett / Matières grasses / Grassi   5,5 g   1,7 g",
            "davon gesättigte Fettsäuren / dont acides gras saturés   2,1 g   0,6 g",
            "Kohlenhydrate / Glucides / Carboidrati   76 g   23 g",
            "davon Zucker / dont sucres / di cui zuccheri   12 g   3,6 g",
            "Ballaststoffe / Fibres alimentaires   3,2 g   1 g",
            "Eiweiss / Protéines / Proteine   9,8 g   2,9 g",
            "Salz / Sel / Sale   0,85 g   0,26 g",
        ])
        #expect(result.per100.kcal == 400)
        #expect(result.per100.fat == 5.5)
        #expect(result.per100.saturatedFat == 2.1)
        #expect(result.per100.carbs == 76)
        #expect(result.per100.sugar == 12)
        #expect(result.per100.fiber == 3.2)
        #expect(result.per100.protein == 9.8)
        #expect(result.per100.salt == 0.85)
        #expect(result.fields.count == 8)
        #expect(!result.isLiquid)
    }

    @Test("Energie als Paar kJ/kcal ohne Einheit an der Zahl")
    func energyPair() {
        let result = NutritionLabelParser.parse(rows: ["Energie kJ/kcal", "1570/375"])
        #expect(result.per100.kcal == 375)
    }

    @Test("Nur kJ: umgerechnet")
    func energyOnlyKilojoule() {
        #expect(NutritionLabelParser.energy(in: ["energie 1046 kj"]) == 250)
    }

    @Test("Ungesättigte Fettsäuren und Natrium werden nicht verwechselt")
    func ignoresLookalikes() {
        let result = NutritionLabelParser.parse(rows: [
            "Fett 20 g",
            "davon einfach ungesättigte Fettsäuren 8 g",
            "davon gesättigte Fettsäuren 6 g",
            "Natrium 0,4 g",
            "Salz 1 g",
        ])
        #expect(result.per100.fat == 20)
        #expect(result.per100.saturatedFat == 6)
        #expect(result.per100.salt == 1)
    }

    @Test("Prozent vom Tagesbedarf zählt nicht, mg wird zu g, pro 100 ml heisst flüssig")
    func percentMilligramLiquid() {
        let result = NutritionLabelParser.parse(rows: [
            "Durchschnittliche Nährwerte pro 100 ml",
            "Energie 180 kJ / 42 kcal 2 %",
            "Zucker 10,6 g 12 %",
            "Salz 20 mg",
        ])
        #expect(result.isLiquid)
        #expect(result.per100.kcal == 42)
        #expect(result.per100.sugar == 10.6)
        #expect(result.per100.salt == 0.02)
    }

    @Test("Schnipsel auf gleicher Höhe werden zu einer Zeile, oben zuerst")
    func groupsRows() {
        let lines = [
            NutritionLabelParser.TextLine(text: "5,5 g", box: CGRect(x: 0.6, y: 0.50, width: 0.1, height: 0.04)),
            NutritionLabelParser.TextLine(text: "Fett", box: CGRect(x: 0.1, y: 0.51, width: 0.2, height: 0.04)),
            NutritionLabelParser.TextLine(text: "Energie", box: CGRect(x: 0.1, y: 0.60, width: 0.2, height: 0.04)),
            NutritionLabelParser.TextLine(text: "400 kcal", box: CGRect(x: 0.6, y: 0.60, width: 0.2, height: 0.04)),
        ]
        #expect(NutritionLabelParser.rows(from: lines) == ["Energie 400 kcal", "Fett 5,5 g"])
        let result = NutritionLabelParser.parse(lines: lines)
        #expect(result.per100.kcal == 400)
        #expect(result.per100.fat == 5.5)
    }

    @Test("Ohne Tabelle: nichts erkannt")
    func nothing() {
        #expect(NutritionLabelParser.parse(rows: ["Zutaten: Weizenmehl, Wasser"]).isEmpty)
    }
}
