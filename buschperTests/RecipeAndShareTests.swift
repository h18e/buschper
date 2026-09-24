import Foundation
import Testing
@testable import buschper

@Suite("Rezepte")
struct RecipeMathTests {
    let ingredients = [
        IngredientAmount(amountG: 500, per100: Nutrients(kcal: 350, carbs: 70, protein: 12)),
        IngredientAmount(amountG: 400, per100: Nutrients(kcal: 25, carbs: 4, fiber: 1.5))
    ]

    @Test("Gesamt aus allen Zutaten")
    func total() {
        let total = RecipeMath.total(ingredients)
        #expect(total.kcal == 1850)
        #expect(total.carbs == 366)
        #expect(total.fiber == 6)
        #expect(RecipeMath.totalWeight(ingredients) == 900)
    }

    @Test("Pro Portion und für 1.5 Portionen")
    func perServing() {
        let perServing = RecipeMath.forServings(1, of: ingredients, recipeServings: 4)
        #expect(perServing.kcal == 462.5)
        let oneAndHalf = RecipeMath.forServings(1.5, of: ingredients, recipeServings: 4)
        #expect((oneAndHalf.kcal ?? 0).isClose(to: 693.75))
    }

    @Test("Portionen auf Viertel gerundet, nie unter einem Viertel")
    func rounding() {
        #expect(RecipeMath.roundedServings(1.4) == 1.5)
        #expect(RecipeMath.roundedServings(0.05) == 0.25)
    }

    @Test("Portionsgrössen beschriften")
    func portionLabels() {
        let slice = PortionChoice(name: "Schiibe", gramsPerUnit: 30)
        #expect(slice.grams(for: 2) == 60)
        #expect(slice.label(count: 2, isLiquid: false) == "2 × Schiibe (60 g)")
        #expect(PortionChoice(name: nil, gramsPerUnit: 1).label(count: 250, isLiquid: true) == "250 ml")
    }
}

@Suite("Mahlzeit teilen")
struct MealShareCodecTests {
    let meal = SharedMeal(
        title: "Zmittag Kantine",
        category: .lunch,
        entries: [
            SharedMeal.Entry(name: "Pasta", amount: 1, unitLabel: "Portion", grams: 350,
                             nutrients: Nutrients(kcal: 650, carbs: 90, fat: 20, protein: 25)),
            SharedMeal.Entry(name: "Salat", amount: 150, unitLabel: "g", grams: 150,
                             nutrients: Nutrients(kcal: 80, fiber: 3))
        ]
    )

    @Test("Datei hin und zurück")
    func fileRoundTrip() throws {
        let data = try MealShareCodec.fileData(for: meal)
        #expect(try MealShareCodec.decode(fileData: data) == meal)
    }

    @Test("QR-Link hin und zurück")
    func qrRoundTrip() throws {
        let url = try #require(MealShareCodec.qrLink(for: meal))
        #expect(url.scheme == "buschper")
        #expect(url.host == "import")
        #expect(try MealShareCodec.decode(url: url) == meal)
    }

    @Test("Eine riesige Mahlzeit passt nicht in einen QR-Code")
    func tooLargeForQR() {
        var huge = meal
        huge.entries = (0..<200).map { index in
            SharedMeal.Entry(name: "Zutat Nummer \(index) mit langem Namen \(UUID().uuidString)",
                             amount: Double(index), unitLabel: "g", grams: Double(index),
                             nutrients: Nutrients(kcal: Double(index) * 1.37, carbs: Double(index) / 3))
        }
        #expect(!MealShareCodec.fitsInQRCode(huge))
        #expect((try? MealShareCodec.fileData(for: huge)) != nil)
    }

    @Test("Fremde Links werden abgelehnt")
    func foreignLink() {
        #expect(throws: MealShareCodec.DecodeError.notABuschperLink) {
            try MealShareCodec.decode(url: URL(string: "https://example.com/?m=abc")!)
        }
    }

    @Test("Neuere Formatversion wird erkannt")
    func newerVersion() throws {
        var future = meal
        future.version = 99
        let data = try MealShareCodec.fileData(for: future)
        #expect(throws: MealShareCodec.DecodeError.unsupportedVersion(99)) {
            try MealShareCodec.decode(fileData: data)
        }
    }

    @Test("Dateiname ohne störende Zeichen")
    func fileName() {
        var named = meal
        named.title = "Pasta / Salat: Mittwoch"
        #expect(MealShareCodec.fileName(for: named) == "Pasta - Salat- Mittwoch.buschper")
    }

    @Test("Base64url ohne Füllzeichen, umkehrbar")
    func base64url() {
        let data = Data([0xfb, 0xff, 0xfe, 0x01])
        let encoded = MealShareCodec.base64URLEncode(data)
        #expect(!encoded.contains("+") && !encoded.contains("/") && !encoded.contains("="))
        #expect(MealShareCodec.base64URLDecode(encoded) == data)
    }
}

@Suite("CSV und Anzeige")
struct CSVAndTextTests {
    @Test("Semikolon, BOM und Anführungszeichen")
    func csv() {
        let csv = CSVWriter.make(header: ["Name", "kcal"], rows: [["Brot; dunkel", "250"], ["\"Spezial\"", ""]])
        #expect(csv.hasPrefix("\u{FEFF}Name;kcal\r\n"))
        #expect(csv.contains("\"Brot; dunkel\";250"))
        #expect(csv.contains("\"\"\"Spezial\"\"\";"))
    }

    @Test("Zahlen im CSV: ganze ohne Komma, sonst zwei Stellen, unbekannt leer")
    func csvNumbers() {
        #expect(CSVWriter.number(250) == "250")
        #expect(CSVWriter.number(12.346) == "12.35")
        #expect(CSVWriter.number(nil) == "")
    }

    @Test("Zehn Nährwert-Spalten in fester Reihenfolge")
    func nutrientColumns() {
        #expect(CSVWriter.nutrientHeader.count == Nutrients.Field.allCases.count)
        #expect(CSVWriter.nutrientFields(Nutrients(kcal: 100)).first == "100")
    }

    @Test("Anzeige von Mengen und Volumen")
    func numberText() {
        #expect(NumberText.amount(150) == "150")
        #expect(NumberText.volume(250) == "250 ml")
        #expect(NumberText.volume(1900) == "1.9 l")
    }
}
