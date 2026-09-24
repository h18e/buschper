import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// Barcode- oder QR-Scan über VisionKit – ohne Drittanbieter und ohne Netz.
/// Aus Frostify übernommen; neu kann er auch QR-Codes geteilter Mahlzeiten lesen.
struct CodeScannerView: View {
    enum Mode {
        case barcode
        case qrCode

        var title: String {
            switch self {
            case .barcode: return "Barcode scanne"
            case .qrCode: return "QR-Code scanne"
            }
        }

        var symbologies: [VNBarcodeSymbology] {
            switch self {
            case .barcode: return [.ean13, .ean8, .upce, .code128, .code39]
            case .qrCode: return [.qr]
            }
        }
    }

    var mode: Mode = .barcode
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuthorized: Bool?
    @State private var manualCode = ""

    private var scannerUsable: Bool {
        DataScannerViewController.isSupported && (cameraAuthorized ?? false)
    }

    var body: some View {
        NavigationStack {
            Group {
                if scannerUsable {
                    DataScannerRepresentable(symbologies: mode.symbologies, onScan: handle)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .bottom) { hint }
                } else {
                    fallback
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbräche") { dismiss() }
                }
            }
            .task { await resolveCameraAccess() }
        }
    }

    private var hint: some View {
        Text(mode == .barcode ? "Code is Bild haute – buschper erkennt ne automatisch." : "QR-Code is Bild haute.")
            .font(.footnote)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 24)
    }

    private var fallback: some View {
        Form {
            Section {
                Text(fallbackMessage)
                    .foregroundStyle(.secondary)
            }
            if mode == .barcode {
                Section {
                    TextField("Code iigäh", text: $manualCode)
                        .keyboardType(.numberPad)
                        .font(.body.monospaced())
                    Button("Übernäh") {
                        handle(manualCode.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Vo Hand")
                } footer: {
                    Text("Dr Simulator het kei Kamera – da chasch e Code trotzdäm iitippe.")
                }
            }
        }
        .themedList()
    }

    private var fallbackMessage: String {
        if cameraAuthorized == false {
            return "buschper darf d Kamera nid bruuche. Das chasch i de iOS-Istellige under Dateschutz → Kamera ändere."
        }
        if !DataScannerViewController.isSupported {
            return "Ds Grät unterstützt dr Scanner nid."
        }
        return "Dr Scanner isch grad nid verfüegbar."
    }

    private func handle(_ code: String) {
        guard !code.isEmpty else { return }
        onScan(code)
        dismiss()
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

/// Dünne Brücke zum UIKit-Scanner.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let symbologies: [VNBarcodeSymbology]
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !context.coordinator.isScanning else { return }
        context.coordinator.isScanning = (try? controller.startScanning()) != nil
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var hasDelivered = false
        var isScanning = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            deliver(from: addedItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            deliver(from: [item])
        }

        /// Nur der erste Treffer zählt – sonst feuert der Scanner laufend nach.
        private func deliver(from items: [RecognizedItem]) {
            guard !hasDelivered else { return }
            for case .barcode(let barcode) in items {
                guard let payload = barcode.payloadStringValue, !payload.isEmpty else { continue }
                hasDelivered = true
                onScan(payload)
                return
            }
        }
    }
}
