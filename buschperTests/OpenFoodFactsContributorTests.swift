import Foundation
import Testing
@testable import buschper

/// Beitrag an Open Food Facts: nur das Nötige, nur wenn sinnvoll.
struct OpenFoodFactsContributorTests {
    private func draft(barcode: String = "7610000000001") -> ProductDraft {
        var draft = ProductDraft()
        draft.name = "Birchermüesli"
        draft.brand = "Hausmarke"
        draft.barcode = barcode
        draft.per100 = Nutrients(kcal: 380.456, carbs: 60, fat: 8.5, protein: 10)
        return draft
    }

    @Test("Neues Produkt: Name, Marke und Nährwerte pro 100 g")
    func newProduct() throws {
        let contribution = try #require(OpenFoodFactsContributor.contribution(for: draft(), isNew: true))
        let fields = OpenFoodFactsContributor.formFields(
            for: contribution, userId: "raphi", password: "geheim", appVersion: "1.0", appUUID: "abc"
        )
        let dict = Dictionary(fields, uniquingKeysWith: { first, _ in first })
        #expect(dict["code"] == "7610000000001")
        #expect(dict["product_name_de"] == "Birchermüesli")
        #expect(dict["brands"] == "Hausmarke")
        #expect(dict["nutrition_data_per"] == "100g")
        #expect(dict["nutriment_energy-kcal"] == "380.46")
        #expect(dict["nutriment_energy-kcal_unit"] == "kcal")
        #expect(dict["nutriment_fat"] == "8.5")
        #expect(dict["nutriment_carbohydrates"] == "60")
        #expect(dict["nutriment_salt"] == nil)
        #expect(dict["app_name"] == "buschper")
        #expect(dict["app_uuid"] == "abc")
    }

    @Test("Ergänzung: Name und Marke von Open Food Facts bleiben unangetastet")
    func completionKeepsName() throws {
        var completing = draft()
        completing.completesOpenFoodFacts = true
        completing.openFoodFactsHadName = true
        completing.origin = .offCopy
        let contribution = try #require(OpenFoodFactsContributor.contribution(for: completing, isNew: true))
        #expect(contribution.name == nil)
        #expect(contribution.brand == nil)
    }

    @Test("Nicht geschickt: ohne Barcode, beim Bearbeiten, bei Korrekturen vollständiger Einträge")
    func notEligible() {
        #expect(OpenFoodFactsContributor.contribution(for: draft(barcode: ""), isNew: true) == nil)
        #expect(OpenFoodFactsContributor.contribution(for: draft(barcode: "12AB"), isNew: true) == nil)
        #expect(OpenFoodFactsContributor.contribution(for: draft(), isNew: false) == nil)
        var correction = draft()
        correction.origin = .offCopy
        #expect(OpenFoodFactsContributor.contribution(for: correction, isNew: true) == nil)
    }

    @Test("Formular sauber kodiert, Antwort ausgewertet")
    func encodingAndOutcome() {
        let body = String(decoding: OpenFoodFactsContributor.formBody([("product_name_de", "Müesli & Co"), ("a", "1+1")]), as: UTF8.self)
        #expect(body == "product_name_de=M%C3%BCesli%20%26%20Co&a=1%2B1")
        #expect(OpenFoodFactsContributor.outcome(from: Data(#"{"status":1,"status_verbose":"fields saved"}"#.utf8)) == .saved)
        #expect(OpenFoodFactsContributor.outcome(from: Data(#"{"status":0,"status_verbose":"no code"}"#.utf8)) == .rejected("no code"))
    }
}
