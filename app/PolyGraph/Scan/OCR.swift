import CoreGraphics
import Foundation
import ImageIO
import UIKit
import Vision

/// Textul de pe cutie / rețetă, citit pe telefon cu Vision. Backend-ul face potrivirea în catalog.
nonisolated enum OCR {
    /// Sincron și lent (≈ 0,5–1,5 s pe o poză de cameră): se cheamă dintr-un `Task.detached`.
    static func recognize(_ image: UIImage, customWords: [String]) throws -> [OCRLine] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        if supported.contains("ro-RO") {
            request.recognitionLanguages = ["ro-RO", "en-US"]
        } else {
            request.automaticallyDetectsLanguage = true
        }
        request.customWords = customWords

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.imageOrientation.cgOrientation)
        try handler.perform([request])

        // Vision întoarce observațiile în ordinea de citire (sus-jos, stânga-dreapta).
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string
                .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
            else { return nil }
            return OCRLine(text: text, height: Double(observation.boundingBox.height))
        }
    }

    /// Numele comerciale ajută corectorul de limbă să nu „repare” „Sintrom” în „Sintron”:
    /// cele ~300 din `brands.txt` (B1), cele ale pacientului demo și cele deja din lista pacientului.
    static func customWords(extra: [String] = []) -> [String] {
        var words = demoBrands + extra
        if let url = Bundle.main.url(forResource: "brands", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            words += text.split(whereSeparator: \.isNewline).map(String.init)
        }
        var seen = Set<String>()
        return words
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static let demoBrands = [
        "Sintrom", "Nurofen", "Simvastatin Terapia", "Amlodipină", "Euthyrox", "Calciu + Vitamina D3",
        "Omeprazol", "Amitriptilina Arena", "Fromilid", "Klacid",
    ]
}

/// Poza trimisă la /scan: latura lungă ≤ 1600 px, JPEG 0.8, orientarea aplicată în pixeli.
nonisolated enum ImageUpload {
    static let maxDimension: CGFloat = 1600
    static let quality: CGFloat = 0.8

    static func jpeg(_ image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

extension UIImage.Orientation {
    nonisolated var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
