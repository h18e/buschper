import CoreData
import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import Vision
import VisionKit

/// Texterkennung auf dem Gerät (Apple Vision). Kein Bild verlässt das iPhone,
/// und es wird nichts gespeichert.
enum NutritionLabelReader {
    static func recognize(_ image: UIImage) async -> [NutritionLabelParser.TextLine] {
        let image = prepared(image)
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                // Zahlen sollen nicht „korrigiert“ werden.
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["de-DE", "fr-FR", "it-IT", "en-US"]
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                    return
                }
                let lines = (request.results ?? []).compactMap { observation -> NutritionLabelParser.TextLine? in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    return NutritionLabelParser.TextLine(text: text, box: observation.boundingBox)
                }
                continuation.resume(returning: lines)
            }
        }
    }

    /// Kamerafotos sind gross (12 MP). Für die Texterkennung reichen 2000 px –
    /// das spart viel Speicher und richtet das Bild gleich auf.
    static func prepared(_ image: UIImage, maxSide: CGFloat = 2000) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide || image.imageOrientation != .up || image.cgImage == nil else { return image }
        let scale = min(1, maxSide / side)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Kamera für die Nährwerttabelle. Nutzt denselben VisionKit-Scanner wie der
/// Barcode-Scan (der zuverlässig läuft) und nimmt auf Knopfdruck ein Foto auf.
struct LabelCameraView: View {
    let onImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuthorized: Bool?
    @State private var handle = LabelScannerHandle()
    @State private var isCapturing = false
    @State private var failed = false

    static var isAvailable: Bool { DataScannerViewController.isSupported }

    var body: some View {
        NavigationStack {
            Group {
                if cameraAuthorized == true {
                    LabelScannerRepresentable(handle: handle)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .bottom) { captureBar }
                } else if cameraAuthorized == false {
                    ContentUnavailableView(
                        "Kei Kamera",
                        systemImage: "camera.fill",
                        description: Text("buschper darf d Kamera nid bruuche. Das chasch i de iOS-Istellige under Dateschutz → Kamera ändere.")
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Nährwärttabelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
            }
            .task { await resolveCameraAccess() }
        }
    }

    private var captureBar: some View {
        VStack(spacing: 12) {
            Text(failed ? "Foti het nid klappet – probier's no einisch." : "Tabelle grad vo vorne is Bild haute.")
                .font(.footnote)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            Button {
                capture()
            } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 64, height: 64)
                    Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                    if isCapturing { ProgressView().tint(.black) }
                }
            }
            .disabled(isCapturing)
            .accessibilityLabel("Foti mache")
        }
        .padding(.bottom, 32)
    }

    private func capture() {
        guard let scanner = handle.controller else { return }
        isCapturing = true
        failed = false
        Task {
            do {
                let image = try await scanner.capturePhoto()
                scanner.stopScanning()
                dismiss()
                // Erst nach dem Schliessen weitergeben, damit das Formular nicht
                // während der Animation umgebaut wird.
                try? await Task.sleep(for: .milliseconds(400))
                onImage(image)
            } catch {
                failed = true
                isCapturing = false
            }
        }
    }

    private func resolveCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            cameraAuthorized = false
        }
    }
}

/// Hält den laufenden Scanner, damit der Auslöser ein Foto anfordern kann.
final class LabelScannerHandle {
    weak var controller: DataScannerViewController?
}

private struct LabelScannerRepresentable: UIViewControllerRepresentable {
    let handle: LabelScannerHandle

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        handle.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !context.coordinator.isScanning else { return }
        context.coordinator.isScanning = (try? controller.startScanning()) != nil
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var isScanning = false
    }
}

/// Abschnitt im Produkt- oder Mahlzeitformular: Nährwerttabelle fotografieren
/// oder aus den Fotos wählen. Nach dem Lesen muss immer gewählt werden, für
/// welche Menge die Werte gelten – erst dann werden sie übernommen (SPEC 5.5).
struct NutritionLabelScanSection: View {
    enum Purpose {
        /// Produktformular: Werte werden pro 100 g/ml gespeichert.
        case product
        /// „Ganzi Mahlzyt“: Werte gelten für das, was gegessen wird.
        case meal

        var bases: [LabelBasis] {
            switch self {
            case .product: return [.per100, .piece, .portion]
            case .meal: return LabelBasis.allCases
            }
        }
    }

    let purpose: Purpose
    /// Kamera und Foto liegen beim Formular, das die Kamera – wie den
    /// Barcode-Scanner – als eigenes Blatt öffnet.
    @Binding var showsCamera: Bool
    @Binding var capturedImage: UIImage?
    /// Gibt die erkannten Werte samt gewählter Menge weiter. `false`, wenn
    /// das Formular damit nichts anfangen kann.
    let onImport: (LabelImport) -> Bool

    @State private var photoItem: PhotosPickerItem?
    @State private var isReading = false
    @State private var message: String?
    @State private var pending: NutritionLabelParser.Result?
    @State private var basis: LabelBasis?
    @State private var grams: Double?
    @State private var count: Double? = 1

    var body: some View {
        Section {
            if let pending {
                choice(for: pending)
            } else {
                if LabelCameraView.isAvailable {
                    Button {
                        showsCamera = true
                    } label: {
                        Label("Nährwärttabelle fotografiere", systemImage: "camera.viewfinder")
                    }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Foti vo dr Tabelle uswähle", systemImage: "photo.on.rectangle")
                }
            }
            if isReading {
                HStack {
                    ProgressView()
                    Text("Lise d Tabelle …").foregroundStyle(Theme.textSecondary)
                }
            }
        } header: {
            Text("Nährwärttabelle")
        } footer: {
            Text(footer)
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            capturedImage = nil
            read(image)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    read(image)
                } else {
                    message = "Das Foti het sech nid la lade."
                }
                photoItem = nil
            }
        }
    }

    // MARK: - Mängi wähle

    @ViewBuilder
    private func choice(for result: NutritionLabelParser.Result) -> some View {
        let unit = result.isLiquid ? "ml" : "g"
        Text("\(result.fields.count) Wärt erkannt: \(result.fields.map(Self.label).joined(separator: ", ")).")
            .font(.subheadline)
        Picker("Wärt gälte für", selection: $basis) {
            Text("Bitte wähle").tag(LabelBasis?.none)
            ForEach(purpose.bases) { item in
                Text(item.label(isLiquid: result.isLiquid)).tag(LabelBasis?.some(item))
            }
        }
        switch (purpose, basis) {
        case (.product, .per100?):
            OptionalNumberField(title: "Portionsgrössi (fakultativ)", value: $grams, unit: unit, fractionDigits: 0)
        case (.product, let chosen?):
            OptionalNumberField(title: "Gwicht vo \(chosen.label(isLiquid: result.isLiquid))", value: $grams, unit: unit, fractionDigits: 0)
        case (.meal, .per100?):
            OptionalNumberField(title: "Gässni Mängi", value: $grams, unit: unit, fractionDigits: 0)
        case (.meal, .piece?), (.meal, .portion?):
            OptionalNumberField(title: "Aazahl", value: $count, unit: basis == .piece ? "Stück" : "Portione")
        default:
            EmptyView()
        }
        HStack {
            Button("Verwärfe", role: .destructive) { reset() }
                .buttonStyle(.borderless)
            Spacer()
            Button("Wärt übernäh") { confirm(result) }
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .disabled(labelImport(for: result).map(isUsable) != true)
        }
    }

    private func labelImport(for result: NutritionLabelParser.Result) -> LabelImport? {
        guard let basis else { return nil }
        return LabelImport(
            values: result.per100, fields: result.fields, isLiquid: result.isLiquid,
            basis: basis, grams: grams, count: count ?? 0
        )
    }

    private func isUsable(_ label: LabelImport) -> Bool {
        switch purpose {
        case .product: return label.per100 != nil
        case .meal: return label.total != nil
        }
    }

    private func confirm(_ result: NutritionLabelParser.Result) {
        guard let label = labelImport(for: result), onImport(label) else { return }
        let names = result.fields.map(Self.label).joined(separator: ", ")
        reset()
        message = "\(result.fields.count) Wärt übernoh (\(names)) für \(label.basis.label(isLiquid: label.isLiquid)). Bitte mit dr Packig vergliche – d Kamera cha sech verläse."
    }

    private func reset() {
        pending = nil
        basis = nil
        grams = nil
        count = 1
    }

    private var footer: String {
        if pending != nil {
            switch purpose {
            case .product:
                return "Wähl, für weli Mängi d Tabelle gilt. Bi Stück oder Portion bruucht's ds Gwicht, denn rächnet buschper uf 100 \(pending?.isLiquid == true ? "ml" : "g") um."
            case .meal:
                return "Wähl, für weli Mängi d Tabelle gilt. Bi 100 g gisch a, wie viel du gässe hesch – d Wärt wärde drnah grächnet."
            }
        }
        return message ?? "buschper list d Wärt us em Foti. D Erkennig lauft ufem iPhone, s Foti wird nid gspycheret."
    }

    // MARK: - Lesen

    private func read(_ image: UIImage) {
        isReading = true
        message = nil
        reset()
        Task {
            let lines = await NutritionLabelReader.recognize(image)
            let result = NutritionLabelParser.parse(lines: lines)
            isReading = false
            if result.isEmpty {
                message = "Kener Nährwärt erkennt. Probier's no einisch: Tabelle grad vo vorne, gnue Liecht, nume d Tabelle im Bild."
            } else {
                pending = result
            }
        }
    }

    static func label(_ field: Nutrients.Field) -> String {
        switch field {
        case .kcal: return "Energie"
        case .carbs: return "Kohlehydrat"
        case .sugar: return "Zucker"
        case .fat: return "Fett"
        case .saturatedFat: return "gsättigti Fettsüüre"
        case .protein: return "Eiwiss"
        case .fiber: return "Ballaststoffe"
        case .salt: return "Salz"
        case .alcohol: return "Alkohol"
        case .caffeine: return "Koffein"
        }
    }
}
