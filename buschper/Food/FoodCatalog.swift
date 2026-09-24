import Foundation
import os

/// Die mitgelieferte Lebensmittelliste: BLV-Daten, falls `tools/import_blv.py`
/// gelaufen ist, sonst die Richtwert-Liste (SPEC 5.4).
final class FoodCatalog {
    struct Item: Decodable {
        let id: String
        let name: String
        let liquid: Bool
        let category: String?
        let per100: Nutrients
    }

    private struct Document: Decodable {
        let source: String
        let items: [Item]
    }

    static let shared = FoodCatalog()
    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "FoodCatalog")

    let items: [Item]
    /// `true`, wenn die echten BLV-Daten geladen sind.
    let isBLV: Bool
    private let byId: [String: Item]

    var sourceLabel: String { isBLV ? "BLV" : "Richtwärt" }

    init(bundle: Bundle = .main) {
        let document = Self.load("blv_foods", bundle: bundle) ?? Self.load("basic_foods", bundle: bundle)
        items = document?.items ?? []
        isBLV = document?.source == "blv"
        byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if items.isEmpty {
            Self.logger.error("Keine Lebensmittelliste im Bundle gefunden.")
        }
    }

    private static func load(_ name: String, bundle: Bundle) -> Document? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        do {
            return try JSONDecoder().decode(Document.self, from: data)
        } catch {
            logger.error("\(name).json nicht lesbar: \(error.localizedDescription)")
            return nil
        }
    }

    func item(id: String) -> Item? { byId[id] }

    func search(_ query: String, limit: Int = 25) -> [Item] {
        FoodSearchRanking.rank(items, query: query, name: \.name, limit: limit)
    }

    func candidate(_ item: Item, isFavorite: Bool) -> FoodCandidate {
        FoodCandidate(
            source: .catalog(item.id),
            name: item.name,
            brand: nil,
            barcode: nil,
            isLiquid: item.liquid,
            per100: item.per100,
            portions: [PortionChoice(name: nil, gramsPerUnit: 1)],
            isFavorite: isFavorite,
            sourceLabel: sourceLabel
        )
    }
}
