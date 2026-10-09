import Foundation
import os

/// Open Food Facts: Barcode-Abfrage und Textsuche (SPEC 5.4).
///
/// Übertragen wird nur der Barcode bzw. der Suchbegriff. Jeder Fehler – kein Netz,
/// Zeitüberschreitung, unbekanntes Produkt – führt zu einem klaren Ergebnis statt
/// einer Sackgasse. Aus Frostify übernommen und um Nährwerte und Suche erweitert.
enum OpenFoodFactsClient {
    struct Product: Equatable {
        var code: String
        /// Leer, wenn Open Food Facts keinen Namen kennt.
        var name: String
        var brand: String?
        var quantityText: String?
        var isLiquid: Bool
        var per100: Nutrients
        /// Portion laut Packung, z. B. 30 g.
        var servingGrams: Double? = nil
        /// In Open Food Facts als „in der Schweiz verkauft“ markiert.
        var isSwiss = false

        /// Genug, um direkt zu erfassen: Name und Energie.
        var isComplete: Bool {
            !name.isEmpty && per100.kcal != nil
        }
    }

    enum LookupResult: Equatable {
        case found(Product)
        /// Open Food Facts kennt den Barcode, aber es fehlen Name oder Energie.
        /// Das Formular startet mit allem, was da ist.
        case incomplete(Product)
        case notFound
        case unavailable
    }

    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "OpenFoodFacts")
    private static let barcodeTimeout: TimeInterval = 8
    private static let fields = [
        "code", "product_name", "product_name_de", "product_name_fr", "product_name_it", "product_name_en",
        "generic_name", "generic_name_de", "brands", "quantity",
        "nutriments", "nutrition_data_per", "serving_size", "serving_quantity", "countries_tags"
    ].joined(separator: ",")

    // MARK: - Barcode

    static func lookup(barcode: String, session: URLSession = .shared) async -> LookupResult {
        let code = barcode.filter { $0.isLetter || $0.isNumber }
        guard !code.isEmpty else { return .notFound }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/product/\(code).json"
        components.queryItems = [URLQueryItem(name: "fields", value: fields)]
        guard let url = components.url else { return .notFound }

        switch await fetch(url, session: session) {
        case .failure(let failure):
            return failure == .notFound ? .notFound : .unavailable
        case .success(let data):
            return lookupResult(from: data, code: code)
        }
    }

    /// Antwort einer Barcode-Abfrage auswerten. Eigene Funktion, damit sie ohne
    /// Netz getestet werden kann.
    static func lookupResult(from data: Data, code: String) -> LookupResult {
        guard let payload = try? JSONDecoder().decode(SinglePayload.self, from: data),
              let product = payload.product?.product(fallbackCode: code)
        else { return .notFound }
        return product.isComplete ? .found(product) : .incomplete(product)
    }

    // MARK: - Suche

    /// Textsuche über **alle** Produkte von Open Food Facts, Schweizer zuerst.
    ///
    /// Früher wurde nur die Schweizer Seite durchsucht. Die zeigt aber nur Produkte,
    /// die jemand als „in der Schweiz verkauft“ markiert hat – viele, die der
    /// Barcode-Scan findet, fehlten deshalb in der Suche.
    ///
    /// Zuerst die neue Suche (search.openfoodfacts.org, schneller und besser
    /// gewichtet). Findet sie zum Wort nichts, sucht sie nach Wortanfängen
    /// („karto“ → „Kartoffel“). Nur wenn sie gar nicht antwortet, kommt die alte,
    /// langsame Suche auf der Weltseite – früher lief die auch bei „nichts
    /// gefunden“ und endete oft in „nicht erreichbar“.
    static func search(_ query: String, session: URLSession = .shared) async -> [Product]? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        if let results = await searchALicious(trimmed, session: session) {
            if !results.isEmpty { return results }
            // Erreichbar, aber nichts zum ganzen Wort: als Wortanfang suchen.
            if let prefix = prefixQuery(for: trimmed),
               let more = await searchALicious(prefix, session: session) {
                return more
            }
            return []
        }

        guard let url = legacySearchURL(for: trimmed) else { return [] }
        switch await fetch(url, session: session, timeout: searchTimeout) {
        case .failure(let failure):
            return failure == .notFound ? [] : nil
        case .success(let data):
            return searchResults(from: data)
        }
    }

    /// Die Suche braucht oft länger als ein Barcode.
    private static let searchTimeout: TimeInterval = 15

    /// `nil`: neue Suche nicht erreichbar oder Antwort unlesbar.
    private static func searchALicious(_ query: String, session: URLSession) async -> [Product]? {
        guard let url = searchALiciousURL(for: query),
              case .success(let data) = await fetch(url, session: session, timeout: searchTimeout)
        else { return nil }
        return searchALiciousResults(from: data)
    }

    /// Letztes Wort als Wortanfang („kartoffel mig“ → „kartoffel mig*“), sobald es
    /// mindestens drei Buchstaben hat. `nil`, wenn das nichts ändert.
    static func prefixQuery(for query: String) -> String? {
        var words = query.split(separator: " ").map(String.init)
        guard let last = words.last, last.count >= 3, last.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        words[words.count - 1] = last + "*"
        return words.joined(separator: " ")
    }

    static func searchALiciousURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.openfoodfacts.org"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "langs", value: "de,fr,it,en"),
            URLQueryItem(name: "page_size", value: "40"),
            URLQueryItem(name: "fields", value: [
                "code", "product_name", "generic_name", "brands", "quantity", "nutriments",
                "nutrition_data_per", "serving_quantity", "countries"
            ].joined(separator: ","))
        ]
        return components.url
    }

    static func legacySearchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "40"),
            URLQueryItem(name: "fields", value: fields)
        ]
        return components.url
    }

    /// Alte Suche: nur, was sich direkt erfassen lässt, Schweizer Produkte zuerst.
    static func searchResults(from data: Data) -> [Product] {
        guard let payload = try? JSONDecoder().decode(SearchPayload.self, from: data) else { return [] }
        return swissFirst((payload.products ?? []).compactMap { $0.product(fallbackCode: nil) }.filter(\.isComplete))
    }

    /// Neue Suche. `nil`, wenn die Antwort nicht lesbar ist (dann übernimmt die alte).
    static func searchALiciousResults(from data: Data) -> [Product]? {
        guard let payload = try? JSONDecoder().decode(SearchALiciousPayload.self, from: data),
              let hits = payload.hits
        else { return nil }
        return swissFirst(hits.compactMap { $0.product }.filter(\.isComplete))
    }

    /// Schweizer Produkte nach vorne, sonst die Reihenfolge der Suche behalten.
    static func swissFirst(_ products: [Product]) -> [Product] {
        products.filter(\.isSwiss) + products.filter { !$0.isSwiss }
    }

    // MARK: - Netz

    private enum Failure: Error, Equatable {
        case notFound
        case unavailable
    }

    private static func fetch(_ url: URL, session: URLSession, timeout: TimeInterval = barcodeTimeout) async -> Result<Data, Failure> {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 404 { return .failure(.notFound) }
                guard http.statusCode == 200 else {
                    logger.info("Open Food Facts antwortet mit \(http.statusCode).")
                    return .failure(.unavailable)
                }
            }
            return .success(data)
        } catch {
            logger.info("Open Food Facts nicht erreichbar: \(error.localizedDescription)")
            return .failure(.unavailable)
        }
    }

    /// Open Food Facts bittet darum, dass sich Anwendungen zu erkennen geben.
    private static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "buschper/\(version) (iOS; https://github.com/h18e/buschper)"
    }

    // MARK: - Antwort

    /// Reines Fett hat rund 900 kcal pro 100 g. Mehr ist ein Erfassungsfehler.
    static let maxKcalPer100 = 950.0

    /// Nährwerte mit einer Endung (`_100g` oder `_serving`) auslesen.
    ///
    /// Energie: kcal, sonst kJ (auch das alte Feld `energy`, das in kJ ist), sonst
    /// aus den Makros gerechnet – aber nur, wenn KH, Eiweiss und Fett alle da sind.
    static func nutrients(_ values: [String: FlexibleNumber], suffix: String) -> Nutrients {
        func value(_ key: String) -> Double? {
            guard let number = values["\(key)\(suffix)"]?.value, number >= 0 else { return nil }
            return number
        }
        var result = Nutrients()
        result.carbs = value("carbohydrates")
        result.sugar = value("sugars")
        result.fat = value("fat")
        result.saturatedFat = value("saturated-fat")
        result.protein = value("proteins")
        result.fiber = value("fiber")
        result.salt = value("salt")
        result.alcohol = value("alcohol").map { $0 * DrinkMath.ethanolDensity }
        // Koffein gibt Open Food Facts in g an, buschper führt mg.
        result.caffeine = value("caffeine").map { $0 * 1000 }

        let kcal = value("energy-kcal")
            ?? value("energy-kj").map { $0 / 4.184 }
            ?? value("energy").map { $0 / 4.184 }
        var fromMacros: Double?
        if let carbs = result.carbs, let protein = result.protein, let fat = result.fat {
            fromMacros = Nutrients.kcal(carbs: carbs, protein: protein, fat: fat, alcohol: result.alcohol)
        }
        if let kcal, kcal > 0, kcal <= maxKcalPer100 {
            result.kcal = kcal
        } else if let fromMacros {
            // Fehlt, ist 0 oder unmöglich hoch (kJ im kcal-Feld): aus den Makros.
            result.kcal = fromMacros
        } else if let kcal, kcal <= maxKcalPer100 {
            result.kcal = kcal
        }
        return result
    }

    private struct SinglePayload: Decodable {
        let product: RawProduct?
    }

    private struct SearchPayload: Decodable {
        let products: [RawProduct]?
    }

    /// Bewusst tolerant: Open Food Facts liefert Zahlen mal als Zahl, mal als Text,
    /// Namen in irgendeiner Sprache und Nährwerte mal pro 100 g, mal pro Portion.
    private struct RawProduct: Decodable {
        let code: String?
        let productName: String?
        let productNameDe: String?
        let productNameFr: String?
        let productNameIt: String?
        let productNameEn: String?
        let genericName: String?
        let genericNameDe: String?
        let brands: String?
        let quantity: String?
        let nutritionDataPer: String?
        let servingSize: String?
        let servingQuantity: FlexibleNumber?
        let nutriments: [String: FlexibleNumber]?
        let countriesTags: [String]?

        enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case productNameDe = "product_name_de"
            case productNameFr = "product_name_fr"
            case productNameIt = "product_name_it"
            case productNameEn = "product_name_en"
            case genericName = "generic_name"
            case genericNameDe = "generic_name_de"
            case brands
            case quantity
            case nutritionDataPer = "nutrition_data_per"
            case servingSize = "serving_size"
            case servingQuantity = "serving_quantity"
            case nutriments
            case countriesTags = "countries_tags"
        }

        /// `nil` nur, wenn weder Name, Marke noch ein einziger Nährwert da ist.
        func product(fallbackCode: String?) -> Product? {
            guard let code = (code?.isEmpty == false ? code : fallbackCode) else { return nil }

            // Deutsch zuerst, dann was es gibt – auch Italienisch und die Sachbezeichnung.
            let name = [productNameDe, productName, productNameFr, productNameIt, productNameEn, genericNameDe, genericName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? ""
            let brand = brands?
                .split(separator: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let values = nutriments ?? [:]
            let servingGrams = servingQuantity?.value.flatMap { $0 > 0 ? $0 : nil }
            var per100 = OpenFoodFactsClient.nutrients(values, suffix: "_100g")
            if per100 == Nutrients(), let servingGrams {
                // Nur Werte pro Portion erfasst: auf 100 g umrechnen.
                per100 = OpenFoodFactsClient.nutrients(values, suffix: "_serving").scaled(by: 100 / servingGrams)
            }

            let hasBrand = brand?.isEmpty == false
            guard !name.isEmpty || hasBrand || per100 != Nutrients() else { return nil }

            let quantityText = quantity?.lowercased() ?? ""
            let servingText = servingSize?.lowercased() ?? ""
            let liquid = nutritionDataPer?.contains("ml") == true
                || quantityText.hasSuffix("ml") || quantityText.hasSuffix(" l") || quantityText.hasSuffix("cl")
                || quantityText.hasSuffix("dl") || servingText.hasSuffix("ml")

            return Product(
                code: code,
                name: name,
                brand: hasBrand ? brand : nil,
                quantityText: quantity,
                isLiquid: liquid,
                per100: per100,
                servingGrams: servingGrams,
                isSwiss: OpenFoodFactsClient.isSwiss(countriesTags ?? [])
            )
        }
    }

    static func isSwiss(_ countries: [String]) -> Bool {
        countries.contains { tag in
            let lower = tag.lowercased()
            return lower.contains("switzerland") || lower.contains("schweiz") || lower.contains("suisse")
        }
    }

    // MARK: Neue Suche (search-a-licious)

    private struct SearchALiciousPayload: Decodable {
        let hits: [SearchHit]?
    }

    /// Ein Treffer der neuen Suche. Sehr nachsichtig: Namen kommen je nach
    /// Index als Text oder pro Sprache, Marken als Text oder Liste. Ein
    /// unlesbares Feld lässt nur dieses Feld weg, nie den ganzen Treffer.
    private struct SearchHit: Decodable {
        let product: Product?

        private enum Keys: String, CodingKey {
            case code
            case productName = "product_name"
            case genericName = "generic_name"
            case brands
            case quantity
            case nutriments
            case nutritionDataPer = "nutrition_data_per"
            case servingQuantity = "serving_quantity"
            case countries
        }

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.container(keyedBy: Keys.self),
                  let code = try? container.decode(String.self, forKey: .code)
            else {
                product = nil
                return
            }
            let names = (try? container.decode(LangText.self, forKey: .productName))?.best
            let generic = (try? container.decode(LangText.self, forKey: .genericName))?.best
            let brands = (try? container.decode(TextList.self, forKey: .brands))?.values ?? []
            let quantity = (try? container.decode(LangText.self, forKey: .quantity))?.best
            let nutriments = (try? container.decode([String: FlexibleNumber].self, forKey: .nutriments)) ?? [:]
            let per = (try? container.decode(String.self, forKey: .nutritionDataPer)) ?? ""
            let serving = (try? container.decode(FlexibleNumber.self, forKey: .servingQuantity))?.value
            let countries = (try? container.decode(TextList.self, forKey: .countries))?.values ?? []

            let raw = RawProduct(
                code: code, productName: names, productNameDe: nil, productNameFr: nil,
                productNameIt: nil, productNameEn: nil, genericName: generic, genericNameDe: nil,
                brands: brands.joined(separator: ","), quantity: quantity, nutritionDataPer: per,
                servingSize: nil, servingQuantity: serving.map { FlexibleNumber(value: $0) },
                nutriments: nutriments, countriesTags: countries
            )
            product = raw.product(fallbackCode: code)
        }
    }

    /// Text oder Text pro Sprache – Deutsch bevorzugt.
    private struct LangText: Decodable {
        let best: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                best = text
            } else if let byLang = try? container.decode([String: String].self) {
                best = ["de", "main", "fr", "it", "en"].compactMap { byLang[$0] }.first { !$0.isEmpty }
                    ?? byLang.values.first { !$0.isEmpty }
            } else {
                best = nil
            }
        }
    }

    /// Text mit Kommas oder Liste.
    private struct TextList: Decodable {
        let values: [String]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let list = try? container.decode([String].self) {
                values = list
            } else if let text = try? container.decode(String.self) {
                values = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                values = []
            }
        }
    }

    struct FlexibleNumber: Decodable {
        let value: Double?

        init(value: Double?) {
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                value = number
            } else if let text = try? container.decode(String.self) {
                value = Double(text.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
        }
    }
}

extension OpenFoodFactsClient.Product {
    /// Gramm bzw. ml, dazu die Portion laut Packung, falls bekannt.
    var portions: [PortionChoice] {
        var result = [PortionChoice(name: nil, gramsPerUnit: 1)]
        if let servingGrams, servingGrams > 0 {
            result.append(PortionChoice(name: "Portion", gramsPerUnit: servingGrams))
        }
        return result
    }

    /// Vorlage fürs Formular, wenn Open Food Facts nicht alles kennt.
    var draft: ProductDraft {
        var draft = ProductDraft()
        draft.name = name
        draft.brand = brand ?? ""
        draft.barcode = code
        draft.isLiquid = isLiquid
        draft.per100 = per100
        if let servingGrams, servingGrams > 0 {
            draft.portions = [ProductDraft.PortionDraft(name: "Portion", grams: servingGrams)]
        }
        draft.origin = .offCopy
        draft.originExternalId = code
        draft.completesOpenFoodFacts = true
        draft.openFoodFactsHadName = !name.isEmpty
        return draft
    }

    func candidate(isFavorite: Bool) -> FoodCandidate {
        FoodCandidate(
            source: .openFoodFacts(code),
            name: name,
            brand: brand,
            barcode: code,
            isLiquid: isLiquid,
            per100: per100,
            portions: portions,
            isFavorite: isFavorite,
            sourceLabel: "Open Food Facts"
        )
    }
}
