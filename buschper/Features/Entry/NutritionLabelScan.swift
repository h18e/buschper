import CoreData
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import Vision

/// Texterkennung auf dem Gerät (Apple Vision). Kein Bild verlässt das iPhone,
/// und es wird nichts gespeichert.
enum NutritionLabelReader {
    static func recognize(_ image: UIImage) async -> [NutritionLabelParser.TextLine] {
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

/// Kamera für ein einzelnes Foto.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Abschnitt im Produktformular: Nährwerttabelle fotografieren oder aus den
/// Fotos wählen, erkannte Werte ins Formular übernehmen.
struct NutritionLabelScanSection: View {
    @Binding var draft: ProductDraft

    @State private var showsCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReading = false
    @State private var message: String?

    var body: some View {
        Section {
            if CameraPicker.isAvailable {
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
        .sheet(isPresented: $showsCamera) {
            CameraPicker { image in read(image) }
                .ignoresSafeArea()
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
