import Foundation
import os

/// Freiwilliger Beitrag an Open Food Facts (SPEC 5.11).
///
/// Nur wenn die Person es in den Einstellungen einschaltet und ein eigenes
/// Open-Food-Facts-Konto hinterlegt. Geschickt werden Barcode, bei neuen
/// Produkten Name und Marke, und die Nährwerte pro 100 g/ml – nie etwas über dich
/// oder deine Mahlzeiten. Die Daten stehen danach öffentlich unter der Lizenz ODbL.
enum OpenFoodFactsContributor {

    struct Contribution: Equatable {
        var code: String
        /// `nil`: Open Food Facts kennt den Namen schon, er wird nicht überschrieben.
        var name: String?
        var brand: String?
        var per100: Nutrients
    }

    enum Outcome: Equatable {
        case saved
        case rejected(String)
        case unavailable
    }

    private static let logger = Logger(subsystem: "ch.hebera.buschper", category: "OpenFoodFactsContributor")
    private static let endpoint = URL(string: "https://world.openfoodfacts.org/cgi/product_jqm2.pl")!

    // MARK: - Was wird geschickt?

    /// Nur für neue Produkte mit Barcode (Open Food Facts kannte sie nicht) und für
    /// Ergänzungen unvollständiger Einträge. Korrekturen vollständiger Einträge
    /// bleiben privat – dort ist unklar, wer recht hat.
    static func contribution(for draft: ProductDraft, isNew: Bool) -> Contribution? {
        let code = draft.barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNew, (8...14).contains(code.count), code.allSatisfy(\.isNumber),
              draft.per100.kcal != nil,
              draft.origin == .own || draft.completesOpenFoodFacts
        else { return nil }

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let sendsName = !draft.completesOpenFoodFacts || !draft.openFoodFactsHadName
        return Contribution(
            code: code,
            name: sendsName && !name.isEmpty ? name : nil,
            brand: !draft.completesOpenFoodFacts && !brand.isEmpty ? brand : nil,
            per100: draft.per100
        )
    }

    /// Nährwerte in der Schreibweise von Open Food Facts. Alkohol und Koffein
    /// bleiben weg: dort gelten andere Einheiten (% vol, g).
    private static let nutrientKeys: [(Nutrients.Field, String, String)] = [
        (.kcal, "energy-kcal", "kcal"),
        (.fat, "fat", "g"),
        (.saturatedFat, "saturated-fat", "g"),
        (.carbs, "carbohydrates", "g"),
        (.sugar, "sugars", "g"),
        (.fiber, "fiber", "g"),
        (.protein, "proteins", "g"),
        (.salt, "salt", "g"),
    ]

    static func formFields(
        for contribution: Contribution,
        userId: String,
        password: String,
        appVersion: String,
        appUUID: String
    ) -> [(String, String)] {
        var fields: [(String, String)] = [
            ("code", contribution.code),
            ("user_id", userId),
            ("password", password),
            ("app_name", "buschper"),
            ("app_version", appVersion),
            ("app_uuid", appUUID),
            ("lc", "de"),
        ]
        if let name = contribution.name {
            fields.append(("lang", "de"))
            fields.append(("product_name_de", name))
        }
        if let brand = contribution.brand {
            fields.append(("brands", brand))
        }
        // Immer der ganze Satz pro 100 g, damit nichts mit Portionswerten vermischt wird.
        fields.append(("nutrition_data_per", "100g"))
        for (field, key, unit) in nutrientKeys {
            guard let value = contribution.per100[field] else { continue }
            fields.append(("nutriment_\(key)", number(value)))
            fields.append(("nutriment_\(key)_unit", unit))
        }
        return fields
    }

    /// Punkt als Dezimaltrennzeichen, höchstens zwei Stellen, ohne Nullen am Ende.
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    static func formBody(_ fields: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    // MARK: - Schicken

    static func send(
        _ contribution: Contribution,
        userId: String,
        password: String,
        appUUID: String,
        session: URLSession = .shared
    ) async -> Outcome {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("buschper/\(version) (iOS; https://github.com/h18e/buschper)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(formFields(
            for: contribution, userId: userId, password: password, appVersion: version, appUUID: appUUID
        ))
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                logger.info("Open Food Facts antwortet beim Schreiben mit \(http.statusCode).")
                return http.statusCode == 403 || http.statusCode == 401
                    ? .rejected("Aamäldig abglehnt – Benutzername oder Passwort prüefe.")
                    : .unavailable
            }
            return outcome(from: data)
        } catch {
            logger.info("Open Food Facts beim Schreiben nicht erreichbar: \(error.localizedDescription)")
            return .unavailable
        }
    }

    static func outcome(from data: Data) -> Outcome {
        struct Payload: Decodable {
            let status: Int?
            let statusVerbose: String?
            enum CodingKeys: String, CodingKey {
                case status
                case statusVerbose = "status_verbose"
            }
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return .rejected("Unerwarteti Antwort vo Open Food Facts.")
        }
        if payload.status == 1 { return .saved }
        return .rejected(payload.statusVerbose ?? "Nid gspycheret.")
    }

    // MARK: - Aus der App

    /// Nach dem Sichern eines Produkts: falls eingeschaltet, im Hintergrund schicken
    /// und das Ergebnis für die Einstellungen merken.
    @MainActor
    static func contributeIfEnabled(_ contribution: Contribution?, displayName: String, preferences: AppPreferences) {
        guard preferences.contributesToOpenFoodFacts, let contribution else { return }
        let userId = preferences.openFoodFactsUserId
        guard !userId.isEmpty, let password = KeychainStore.password(for: userId) else {
            preferences.openFoodFactsLastResult = "✗ \(displayName): Kes Konto hinterleit."
            return
        }
        let appUUID = preferences.openFoodFactsAppUUID
        Task { @MainActor in
            let outcome = await send(contribution, userId: userId, password: password, appUUID: appUUID)
            let date = Date().formatted(date: .abbreviated, time: .shortened)
            switch outcome {
            case .saved:
                preferences.openFoodFactsLastResult = "✓ \(displayName) (\(contribution.code)) gschickt – \(date)"
            case .rejected(let reason):
                preferences.openFoodFactsLastResult = "✗ \(displayName): \(reason) – \(date)"
            case .unavailable:
                preferences.openFoodFactsLastResult = "✗ \(displayName): Open Food Facts nid erreichbar – \(date). Nid nomau gschickt."
            }
        }
    }
}
