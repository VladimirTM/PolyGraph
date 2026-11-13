import CoreGraphics
import Foundation
import Observation
import OSLog
import UIKit

enum ScanMode: String, CaseIterable, Identifiable {
    case box
    case prescription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .box: "Cutie"
        case .prescription: "Rețetă"
        }
    }

    var kind: ScanKind {
        switch self {
        case .box: .box
        case .prescription: .prescription
        }
    }
}

/// Ce s-a salvat după scanare; lista îl transformă în mesajul de finalizare.
struct ScanOutcome: Equatable {
    let savedCount: Int
    let newAlerts: Int
}

/// Răspunsul de la /scan plus ce s-a trimis (poza pentru sheet, OCR-ul pentru exportul din Debug).
struct ScanConfirmation: Identifiable {
    let id = UUID()
    let result: ExtractionResult
    let photo: UIImage?
    let kind: ScanKind
    let ocrLines: [OCRLine]
    let datamatrix: String?
}

/// Starea ecranului de scanare: cod citit → poză → OCR pe telefon → /scan → confirmare.
@Observable
final class ScanModel {
    enum Status: Equatable {
        case aiming
        case codeRead
        case reading
        case matching
        case recognized(String)
        case failed(String)
    }

    var mode: ScanMode
    private(set) var status: Status = .aiming
    /// conținutul brut al DataMatrix-ului GS1 citit; schimbarea lui din nil declanșează conturul și haptic-ul
    private(set) var scannedCode: String?
    private(set) var codeCorners: [CGPoint] = []
    private(set) var capturedImage: UIImage?
    var confirmation: ScanConfirmation?
    private(set) var errorCount = 0

    let proxy = BoxScannerProxy()
    /// `PG_FAKE_SCAN` (doar Debug): camera e înlocuită de o poză și un cod din fixture
    let fakeScan: String?

    @ObservationIgnored private var probeTask: Task<Void, Never>?
    @ObservationIgnored private var lastSubmission: Submission?

    private struct Submission {
        let image: UIImage?
        let kind: ScanKind
        let datamatrix: String?
    }

    init(fakeScan: String? = DebugEnvironment.current.fakeScan) {
        self.fakeScan = fakeScan
        #if DEBUG
        mode = fakeScan.map { FakeScan.sample(named: $0).mode } ?? .box
        #else
        mode = .box
        #endif
    }

    var isWorking: Bool {
        switch status {
        case .reading, .matching, .recognized: true
        default: false
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = status { message } else { nil }
    }

    /// Textul din pastila de sus (stările de status, skill §16).
    var guidance: String? {
        switch status {
        case .aiming: mode == .box ? "Arătați codul pătrat de pe cutie" : "Fotografiați toată foaia rețetei"
        case .codeRead: "Am citit codul. Acum fotografiați fața cutiei."
        case .reading: mode == .box ? "Citesc cutia…" : "Citesc rețeta…"
        case .matching: "Caut substanța activă…"
        case .recognized(let name): "Am recunoscut cutia: \(name)"
        case .failed: nil
        }
    }

    // MARK: - Evenimente de la cameră

    func codeDetected(_ raw: String, corners: [CGPoint], store: AppStore) {
        guard mode == .box, !isWorking, errorMessage == nil, confirmation == nil else { return }
        if let scannedCode {
            if raw == scannedCode { codeCorners = corners }
            return
        }
        // alte coduri pătrate de pe cutie (nu GS1) se ignoră
        guard (try? GS1.parse(raw)) != nil else { return }
        scannedCode = raw
        codeCorners = corners
        status = .codeRead
        Log.scan.info("DataMatrix citit")
        probeKnownBox(raw, store: store)
    }

    /// Butonul de declanșare: poza feței cutiei (cu sau fără cod citit; fără cod e rezerva).
    func capture(store: AppStore) async {
        guard !isWorking else { return }
        probeTask?.cancel()
        let image: UIImage
        #if DEBUG
        if let fakeScan {
            await submit(image: FakeScan.sample(named: fakeScan).image, kind: .box, datamatrix: scannedCode, store: store)
            return
        }
        #endif
        do {
            image = try await proxy.capturePhoto()
        } catch {
            fail(Self.message(for: error))
            return
        }
        await submit(image: image, kind: .box, datamatrix: scannedCode, store: store)
    }

    func prescriptionScanned(_ image: UIImage, store: AppStore) async {
        await submit(image: image, kind: .prescription, datamatrix: nil, store: store)
    }

    func cameraFailed(_ error: Error) {
        fail(Self.message(for: error))
    }

    func retry(store: AppStore) async {
        guard let last = lastSubmission else {
            reset()
            return
        }
        await submit(image: last.image, kind: last.kind, datamatrix: last.datamatrix, store: store)
    }

    /// „Completez manual”: același sheet de confirmare, cu un medicament gol (și GTIN-ul, dacă s-a citit codul).
    func startManualEntry() {
        probeTask?.cancel()
        let code = scannedCode.flatMap { try? GS1.parse($0) }
        let blank = MedDraft.blankItem(code: code)
        confirmation = ScanConfirmation(
            result: ExtractionResult(candidates: [blank], rawText: nil, warnings: []),
            photo: capturedImage, kind: mode.kind, ocrLines: [], datamatrix: scannedCode)
    }

    /// După „Renunță” în sheet, sau la schimbarea modului: se poate scana din nou.
    func reset() {
        probeTask?.cancel()
        status = .aiming
        scannedCode = nil
        codeCorners = []
        capturedImage = nil
        lastSubmission = nil
    }

    // MARK: - Trimiterea

    private func submit(image: UIImage?, kind: ScanKind, datamatrix: String?, store: AppStore) async {
        lastSubmission = Submission(image: image, kind: kind, datamatrix: datamatrix)
        capturedImage = image
        status = .reading

        let words = OCR.customWords(extra: store.meds.map(\.product.brand))
        let prepared = await Task.detached(priority: .userInitiated) { () -> ([OCRLine], Data?) in
            guard let image else { return ([], nil) }
            let lines = (try? OCR.recognize(image, customWords: words)) ?? []
            return (lines, ImageUpload.jpeg(image))
        }.value
        Log.scan.info("OCR: \(prepared.0.count) linii")

        status = .matching
        guard let patientID = store.settings.patientID else {
            fail(APIError.missingToken.errorDescription ?? "")
            return
        }
        do {
            let result = try await store.api.scan(
                patientID: patientID, kind: kind, ocrLines: prepared.0, image: prepared.1, datamatrix: datamatrix)
            guard !result.candidates.isEmpty else {
                fail(result.warnings.first
                    ?? (kind == .box ? "Nu am putut citi cutia, completați manual." : "Nu am putut citi rețeta, completați manual."))
                return
            }
            confirmation = ScanConfirmation(
                result: Self.withScannedCode(result, kind: kind, datamatrix: datamatrix),
                photo: image, kind: kind, ocrLines: prepared.0, datamatrix: datamatrix)
        } catch {
            fail(Self.message(for: error))
        }
    }

    /// Cutie deja confirmată o dată (cache pe GTIN): nu mai e nevoie de poză.
    private func probeKnownBox(_ raw: String, store: AppStore) {
        guard let patientID = store.settings.patientID else { return }
        let api = store.api
        probeTask = Task { [weak self] in
            guard let result = try? await api.scan(patientID: patientID, kind: .box, datamatrix: raw),
                  let first = result.candidates.first, first.match.method == .gtinCache
            else { return }
            guard let self, !Task.isCancelled, self.status == .codeRead else { return }
            self.status = .recognized(first.displayName)
            // cât să se citească pastila înainte să apară sheet-ul
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, case .recognized = self.status else { return }
            self.confirmation = ScanConfirmation(
                result: Self.withScannedCode(result, kind: .box, datamatrix: raw),
                photo: nil, kind: .box, ocrLines: [], datamatrix: raw)
        }
    }

    /// O cutie = un candidat; codul citit îi completează / corectează GTIN-ul, expirarea și lotul.
    static func withScannedCode(_ result: ExtractionResult, kind: ScanKind, datamatrix: String?) -> ExtractionResult {
        guard kind == .box, result.candidates.count == 1,
              let datamatrix, let code = try? GS1.parse(datamatrix)
        else { return result }
        return result.with(candidates: [MedDraft.applying(code, to: result.candidates[0])])
    }

    private func fail(_ message: String) {
        status = .failed(message)
        errorCount += 1
        Log.scan.error("Scanare eșuată: \(message, privacy: .public)")
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Nu am putut citi. Încercați din nou."
    }
}
