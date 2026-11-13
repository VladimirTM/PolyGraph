import OSLog
import SwiftUI
import UIKit
import Vision
import VisionKit

/// Legătura dintre ecranul de scanare și `DataScannerViewController` (pentru `capturePhoto()`).
final class BoxScannerProxy {
    weak var scanner: DataScannerViewController?

    static var isSupported: Bool { DataScannerViewController.isSupported }
    static var isAvailable: Bool { DataScannerViewController.isAvailable }

    /// Pe iPhone, prima captură poate eșua (AVFoundation -11800 / -16802) dacă sesiunea camerei
    /// tocmai s-a reconfigurat; a doua încercare, după o pauză scurtă, de obicei reușește.
    func capturePhoto() async throws -> UIImage {
        guard let scanner else { throw ScanError.cameraUnavailable }
        do {
            return try await scanner.capturePhoto()
        } catch {
            Log.scan.error("capturePhoto, prima încercare: \(String(describing: error), privacy: .public)")
            try? await Task.sleep(for: .milliseconds(400))
            if !scanner.isScanning { try? scanner.startScanning() }
            do {
                return try await scanner.capturePhoto()
            } catch {
                Log.scan.error("capturePhoto, a doua încercare: \(String(describing: error), privacy: .public)")
                throw ScanError.photoFailed
            }
        }
    }
}

/// Camera pentru cutie: caută doar DataMatrix; poza feței se face cu același controller.
struct BoxScannerView: UIViewControllerRepresentable {
    let proxy: BoxScannerProxy
    /// conținutul codului și colțurile lui, în coordonatele acestui view
    let onCode: (String, [CGPoint]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.dataMatrix])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            // urmărirea la frecvență mare încarcă sesiunea și face `capturePhoto()` să eșueze
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        proxy.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        proxy.scanner = scanner
        if !scanner.isScanning {
            do {
                try scanner.startScanning()
            } catch {
                Log.scan.error("startScanning: \(String(describing: error), privacy: .public)")
            }
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String, [CGPoint]) -> Void

        init(onCode: @escaping (String, [CGPoint]) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]
        ) {
            report(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(allItems)
        }

        private func report(_ items: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue else { continue }
                let b = barcode.bounds
                onCode(payload, [b.topLeft, b.topRight, b.bottomRight, b.bottomLeft])
                return
            }
        }
    }
}

/// Rețeta: camera de documente a sistemului decupează și îndreaptă foaia. Se trimite prima pagină.
struct PrescriptionScannerView: UIViewControllerRepresentable {
    let onScan: (UIImage) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ camera: VNDocumentCameraViewController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: PrescriptionScannerView

        init(parent: PrescriptionScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                parent.onCancel()
                return
            }
            parent.onScan(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }
    }
}

enum ScanError: LocalizedError {
    case cameraUnavailable
    case photoFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: "Camera nu e pornită. Închideți ecranul și încercați din nou."
        case .photoFailed: "Nu am putut face poza. Țineți telefonul nemișcat și încercați din nou."
        }
    }
}
