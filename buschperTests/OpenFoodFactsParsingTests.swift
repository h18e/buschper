import Foundation
import Testing
@testable import buschper

/// Open Food Facts vollständig auswerten: Lücken führen nicht mehr zu „unbekannt“.
struct OpenFoodFactsParsingTests {
    private func lookup(_ json: String, code: String = "7610000000001") -> OpenFoodFactsClient.LookupResult {
        OpenFoodFactsClient.lookupResult(from: Data(json.utf8), code: code)
    }

    private func product(_ result: OpenFoodFactsClient.LookupResult) -> OpenFoodFactsClient.Product? {
        switch result {
        case .found(let product), .incomplete(let product): return product
        case .notFound, .unavailable: return nil
        }
    }

    @Test("Energie nur in kJ wird zu kcal")
    func energyInKilojoule() {
        let result = lookup(#"{"product":{"product_name":"Zwieback","nutriments":{"energy-kj_100g":1674,"fat_100g":"5,5"}}}"#)
        guard case .found(let product) = result else {
            Issue.record("Erwartet: gefunden, war \(result)")
            return
        }
        #expect((product.per100.kcal ?? 0).isClose(to: 400.1, tolerance: 0.1))
        #expect(product.per100.fat == 5.5)
    }

    @Test("Werte nur pro Portion werden auf 100 g umgerechnet")
    func perServingOnly() {
        let result = lookup(#"{"product":{"product_name_de":"Riegel","serving_size":"25 g","serving_quantity":"25","nutriments":{"energy-kcal_serving":100,"proteins_serving":2.5}}}"#)
        let item = product(result)
        #expect(item?.per100.kcal == 400)
        #expect(item?.per100.protein == 10)
        #expect(item?.servingGrams == 25)
        #expect(item?.portions.last == PortionChoice(name: "Portion", gramsPerUnit: 25))
    }

    @Test("Ohne Energie, aber mit KH, Eiweiss und Fett: aus den Makros gerechnet")
    func energyFromMacros() {
        let result = lookup(#"{"product":{"product_name":"Joghurt","nutriments":{"carbohydrates_100g":10,"proteins_100g":4,"fat_100g":3}}}"#)
        #expect(product(result)?.per100.kcal == 83)
    }

    @Test("Unmögliche kcal (kJ im falschen Feld) werden durch die Makros ersetzt")
    func impossibleKcal() {
        let result = lookup(#"{"product":{"product_name":"Brot","nutriments":{"energy-kcal_100g":1050,"carbohydrates_100g":50,"proteins_100g":8,"fat_100g":2}}}"#)
        #expect(product(result)?.per100.kcal == 250)
    }

    @Test("Name nur auf Italienisch reicht")
    func italianName() {
        let result = lookup(#"{"product":{"product_name_it":"Biscotti","nutriments":{"energy-kcal_100g":480}}}"#)
        guard case .found(let item) = result else {
            Issue.record("Erwartet: gefunden, war \(result)")
            return
        }
        #expect(item.name == "Biscotti")
    }

    @Test("Bekannt, aber ohne Nährwerte: Formular vorausgefüllt statt „unbekannt“")
    func incompleteBecomesDraft() {
        let result = lookup(#"{"product":{"product_name":"Eistee","brands":"Migros, M-Budget","quantity":"1.5 l","nutriments":{}}}"#, code: "7613404000000")
        guard case .incomplete(let item) = result else {
            Issue.record("Erwartet: unvollständig, war \(result)")
            return
        }
        let draft = item.draft
        #expect(draft.name == "Eistee")
        #expect(draft.brand == "Migros")
        #expect(draft.barcode == "7613404000000")
        #expect(draft.isLiquid)
        #expect(draft.completesOpenFoodFacts)
        #expect(draft.openFoodFactsHadName)
        #expect(draft.per100.kcal == nil)
    }

    @Test("Ganz leerer Eintrag gilt als unbekannt")
    func emptyIsNotFound() {
        #expect(lookup(#"{"product":{"nutriments":{}}}"#) == .notFound)
        #expect(lookup(#"{"status":0}"#) == .notFound)
    }

    @Test("Die Suche zeigt nur direkt erfassbare Produkte")
    func searchFiltersIncomplete() {
        let json = #"{"products":[{"code":"1","product_name":"Voll","nutriments":{"energy-kcal_100g":50}},{"code":"2","product_name":"Leer","nutriments":{}}]}"#
        let results = OpenFoodFactsClient.searchResults(from: Data(json.utf8))
        #expect(results.map(\.name) == ["Voll"])
    }

    @Test("Alte Suche: Schweizer Produkte zuerst, sonst Reihenfolge behalten")
    func legacySwissFirst() {
        let json = #"{"products":[{"code":"1","product_name":"A","countries_tags":["en:france"],"nutriments":{"energy-kcal_100g":50}},{"code":"2","product_name":"B","countries_tags":["en:switzerland"],"nutriments":{"energy-kcal_100g":60}},{"code":"3","product_name":"C","nutriments":{"energy-kcal_100g":70}}]}"#
        let results = OpenFoodFactsClient.searchResults(from: Data(json.utf8))
        #expect(results.map(\.name) == ["B", "A", "C"])
    }

    @Test("Neue Suche: Namen als Text oder pro Sprache, Marken als Liste")
    func searchALicious() throws {
        let json = #"""
        {"hits":[
          {"code":"7610000000001","product_name":{"main":"Lait entier","de":"Vollmilch"},"brands":["Migros","M-Classic"],
           "countries":["en:switzerland"],"nutriments":{"energy-kcal_100g":64,"proteins_100g":3.3},"quantity":"1 l"},
          {"code":"3000000000002","product_name":"Biscuits","brands":"Lu","countries":["en:france"],
           "nutriments":{"energy-kcal_100g":480},"serving_quantity":"25"},
          {"code":"3000000000003","product_name":"Ohne Werte","nutriments":{}},
          {"product_name":"Ohne Barcode","nutriments":{"energy-kcal_100g":10}},
          {"code":"3000000000004","product_name":12,"brands":{"x":1},"nutriments":{"energy-kcal_100g":"55"}}
        ],"count":5}
        """#
        let results = try #require(OpenFoodFactsClient.searchALiciousResults(from: Data(json.utf8)))
        #expect(results.map(\.code) == ["7610000000001", "3000000000002"])
        #expect(results[0].name == "Vollmilch")
        #expect(results[0].brand == "Migros")
        #expect(results[0].isSwiss)
        #expect(results[0].isLiquid)
        #expect(results[1].servingGrams == 25)
    }

    @Test("Halbes Wort wird als Wortanfang gesucht")
    func prefixQuery() {
        #expect(OpenFoodFactsClient.prefixQuery(for: "karto") == "karto*")
        #expect(OpenFoodFactsClient.prefixQuery(for: "kartoffel mig") == "kartoffel mig*")
        #expect(OpenFoodFactsClient.prefixQuery(for: "ka") == nil)
        #expect(OpenFoodFactsClient.prefixQuery(for: "karto*") == nil)
    }

    @Test("Unlesbare Antwort der neuen Suche: zurück zur alten")
    func searchALiciousUnreadable() {
        #expect(OpenFoodFactsClient.searchALiciousResults(from: Data(#"{"errors":["boom"]}"#.utf8)) == nil)
        #expect(OpenFoodFactsClient.searchALiciousResults(from: Data("<html>".utf8)) == nil)
    }
}
