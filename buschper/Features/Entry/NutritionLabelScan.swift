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

/// Abschnitt im Produktformular: Nährwerttabelle fotografieren oder aus den
/// Fotos wählen, erkannte Werte ins Formular übernehmen.
struct NutritionLabelScanSection: View {
    @Binding var draft: ProductDraft
    /// Kamera und Foto liegen beim Formular, das die Kamera – wie den
    /// Barcode-Scanner – als eigenes Blatt öffnet.
    @Binding var showsCamera: Bool
    @Binding var capturedImage: UIImage?

    @State private var photoItem: PhotosPickerItem?
    @State private var isReading = false
    @State private var message: String?

    var body: some View {
        Section {
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
            if isReading {
                HStack {
                    ProgressView()
                    Text("Lise d Tabelle …").foregroundStyle(Theme.textSecondary)
                }
            }
        } footer: {
            Text(message ?? "buschper list d Wärt us em Foti u füllt se unde i. D Erkennig lauft ufem iPhone, s Foti wird nid gspycheret.")
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

    private func read(_ image: UIImage) {
        isReading = true
        message = nil
        Task {
            let lines = await NutritionLabelReader.recognize(image)
            let result = NutritionLabelParser.parse(lines: lines)
            apply(result)
            isReading = false
        }
    }

    private func apply(_ result: NutritionLabelParser.Result) {
        guard !result.isEmpty else {
            message = "Kener Nährwärt erkennt. Probier's no einisch: Tabelle grad vo vorne, gnue Liecht, nume d Tabelle im Bild."
            return
        }
        for field in result.fields {
            draft.per100[field] = result.per100[field]
        }
        if result.isLiquid { draft.isLiquid = true }
        let names = result.fields.map(Self.label).joined(separator: ", ")
        message = "\(result.fields.count) Wärt übernoh (\(names)). Bitte mit dr Packig vergliche – d Kamera cha sech verläse."
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
