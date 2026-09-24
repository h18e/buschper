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
        var name: String
        var brand: String?
        var quantityText: String?
        var isLiquid: Bool
        var per100: Nutrients
    }

    enum LookupResult: Equatable {
        case found(Product)
        case notFound
        case unavailable
    }

    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "OpenFoodFacts")
    private static let timeout: TimeInterval = 8
    private static let fields = [
        "code", "product_name", "product_name_de", "product_name_fr", "brands", "quantity",
        "nutriments", "nutrition_data_per"
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
            guard let payload = try? JSONDecoder().decode(SinglePayload.self, from: data),
                  let product = payload.product?.product(fallbackCode: code)
            else { return .notFound }
            return .found(product)
        }
    }

    // MARK: - Suche

    /// Sucht auf der Schweizer Seite von Open Food Facts, damit Produkte aus
    /// Schweizer Läden zuerst kommen.
    static func search(_ query: String, session: URLSession = .shared) async -> [Product]? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "ch.openfoodfacts.org"
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: fields)
        ]
        guard let url = components.url else { return [] }

        switch await fetch(url, session: session) {
        case .failure(let failure):
            return failure == .notFound ? [] : nil
        case .success(let data):
            guard let payload = try? JSONDecoder().decode(SearchPayload.self, from: data) else { return [] }
            return (payload.products ?? []).compactMap { $0.product(fallbackCode: nil) }
        }
    }

    // MARK: - Netz

    private enum Failure: Error, Equatable {
        case notFound
        case unavailable
    }

    private static func fetch(_ url: URL, session: URLSession) async -> Result<Data, Failure> {
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

    private struct SinglePayload: Decodable {
        let product: RawProduct?
    }

    private struct SearchPayload: Decodable {
        let products: [RawProduct]?
    }

    /// Bewusst tolerant: Open Food Facts liefert Zahlen mal als Zahl, mal als Text.
    private struct RawProduct: Decodable {
        let code: String?
        let productName: String?
        let productNameDe: String?
        let productNameFr: String?
        let brands: String?
        let quantity: String?
        let nutritionDataPer: String?
        let nutriments: [String: FlexibleNumber]?

        enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case productNameDe = "product_name_de"
            case productNameFr = "product_name_fr"
            case brands
            case quantity
            case nutritionDataPer = "nutrition_data_per"
            case nutriments
        }

        func product(fallbackCode: String?) -> Product? {
            let candidates = [productNameDe, productName, productNameFr]
            guard let name = candidates
                .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty }),
                  let code = (code?.isEmpty == false ? code : fallbackCode)
            else { return nil }

            let values = nutriments ?? [:]
            func value(_ key: String) -> Double? { values["\(key)_100g"]?.value }

            var per100 = Nutrients()
            per100.kcal = value("energy-kcal") ?? value("energy").map { $0 / 4.184 }
            per100.carbs = value("carbohydrates")
            per100.sugar = value("sugars")
            per100.fat = value("fat")
            per100.saturatedFat = value("saturated-fat")
            per100.protein = value("proteins")
            per100.fiber = value("fiber")
            per100.salt = value("salt")
            per100.alcohol = value("alcohol").map { $0 * DrinkMath.ethanolDensity }
            // Koffein gibt Open Food Facts in g an, buschper führt mg.
            per100.caffeine = value("caffeine").map { $0 * 1000 }

            guard per100.kcal != nil else { return nil }

            let brand = brands?
                .split(separator: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let quantityText = quantity?.lowercased() ?? ""
            let liquid = nutritionDataPer?.contains("ml") == true
                || quantityText.hasSuffix("ml") || quantityText.hasSuffix(" l") || quantityText.hasSuffix("cl")
                || quantityText.hasSuffix("dl")

            return Product(
                code: code,
                name: name,
                brand: (brand?.isEmpty == false) ? brand : nil,
                quantityText: quantity,
                isLiquid: liquid,
                per100: per100
            )
        }
    }

    private struct FlexibleNumber: Decodable {
        let value: Double?

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
    func candidate(isFavorite: Bool) -> FoodCandidate {
        FoodCandidate(
            source: .openFoodFacts(code),
            name: name,
            brand: brand,
            barcode: code,
            isLiquid: isLiquid,
            per100: per100,
            portions: [PortionChoice(name: nil, gramsPerUnit: 1)],
            isFavorite: isFavorite,
            sourceLabel: "Open Food Facts"
        )
    }
}
