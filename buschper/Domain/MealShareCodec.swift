import Foundation

/// Eine geteilte Mahlzeit – nur buschper ↔ buschper, ohne Server (SPEC 6).
///
/// Enthält bewusst **kein Datum** und nichts über die Person: nur, was man zum
/// Nachkochen oder Nacherfassen braucht.
struct SharedMeal: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var name: String
        var amount: Double
        var unitLabel: String
        var grams: Double
        var nutrients: Nutrients
    }

    /// Formatversion. Neuere buschper-Versionen können ältere Dateien lesen.
    var version: Int = 1
    var title: String
    var category: MealCategory
    var entries: [Entry]

    var total: Nutrients {
        NutrientSum(entries.map(\.nutrients)).values
    }
}

enum MealShareCodec {
    enum DecodeError: Error, Equatable {
        case notABuschperLink
        case unreadable
        case unsupportedVersion(Int)
    }

    static let fileExtension = "buschper"
    static let urlScheme = "buschper"
    static let urlHost = "import"
    static let urlParameter = "m"
    static let supportedVersion = 1

    /// Ein QR-Code fasst in der gröbsten Fehlerkorrektur knapp 3 KB Text. Mit
    /// Reserve für das Schema bleibt diese Grenze.
    static let qrPayloadLimit = 2_600

    // MARK: - Datei

    static func fileData(for meal: SharedMeal) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(meal)
    }

    static func decode(fileData: Data) throws -> SharedMeal {
        let meal: SharedMeal
        do {
            meal = try JSONDecoder().decode(SharedMeal.self, from: fileData)
        } catch {
            throw DecodeError.unreadable
        }
        guard meal.version <= supportedVersion else {
            throw DecodeError.unsupportedVersion(meal.version)
        }
        return meal
    }

    /// Dateiname ohne Zeichen, die in Dateisystemen oder Messengern stören.
    static func fileName(for meal: SharedMeal) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = meal.title.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let base = String(cleaned).trimmingCharacters(in: .whitespaces)
        return "\(base.isEmpty ? "Mahlzyt" : base).\(fileExtension)"
    }

    // MARK: - QR-Link

    /// `buschper://import?m=<base64url(zlib(json))>`, oder `nil`, wenn die
    /// Mahlzeit zu gross für einen QR-Code ist.
    static func qrLink(for meal: SharedMeal) -> URL? {
        guard let json = try? fileData(for: meal),
              let compressed = try? (json as NSData).compressed(using: .zlib) as Data
        else { return nil }
        let payload = base64URLEncode(compressed)
        guard payload.count <= qrPayloadLimit else { return nil }

        var components = URLComponents()
        components.scheme = urlScheme
        components.host = urlHost
        components.queryItems = [URLQueryItem(name: urlParameter, value: payload)]
        return components.url
    }

    static func fitsInQRCode(_ meal: SharedMeal) -> Bool {
        qrLink(for: meal) != nil
    }

    static func decode(url: URL) throws -> SharedMeal {
        guard url.scheme == urlScheme, url.host == urlHost,
              let payload = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == urlParameter })?.value,
              let compressed = base64URLDecode(payload)
        else {
            throw DecodeError.notABuschperLink
        }
        guard let json = try? (compressed as NSData).decompressed(using: .zlib) as Data else {
            throw DecodeError.unreadable
        }
        return try decode(fileData: json)
    }

    // MARK: - Base64url

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
