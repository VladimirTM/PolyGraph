#if DEBUG
import SwiftUI
import UIKit

/// Camera falsă pentru simulator (`PG_FAKE_SCAN`, tabelul Q0): o poză și, pentru cutii, codul din
/// `contracts/fixtures/gs1_cases.json`. Fluxul de după (OCR, upload, confirmare) e cel real.
enum FakeScan {
    struct Sample {
        let mode: ScanMode
        let datamatrix: String?
        let image: UIImage
    }

    static func sample(named name: String) -> Sample {
        let key = name.lowercased()
        let sintrom = ["Sintrom", "4 mg", "Acenocumarol", "30 comprimate"]
        let spec: (ScanMode, String?, [String]) =
            switch key {
            case "sintrom":
                (.box, "]d2010594900000001417280331\u{1D}10AB123\u{1D}21SN0001", sintrom)
            case "nurofen":
                (.box, "010594900000002121XYZ987654\u{1D}1727093010L2026A",
                 ["Nurofen", "400 mg", "Ibuprofen", "24 comprimate filmate"])
            case "expired", "sintrom_expired":
                (.box, "010594900000001417240131\u{1D}10OLD1", sintrom)
            case "klacid_rx", "fromilid_rx", "rx":
                (.prescription, nil,
                 ["Rp./", "Fromilid 500 mg", "comprimate filmate, 14 buc.", "1-0-1, 7 zile", "Dr. Ionescu, ORL"])
            case "unreadable":
                (.box, nil, [])
            default:
                (.box, nil, [name])
            }
        let image = bundledImage(key) ?? render(lines: spec.2)
        return Sample(mode: spec.0, datamatrix: spec.1, image: image)
    }

    /// Pozele reale ale cutiilor demo, dacă au fost puse în `DebugAssets/` (din `demo/photos/`).
    private static func bundledImage(_ name: String) -> UIImage? {
        for ext in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path()) {
                return image
            }
        }
        return nil
    }

    /// Fără poză reală: textul tipărit pe alb, ca OCR-ul de pe simulator să citească ceva.
    private static func render(lines: [String]) -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            (lines.isEmpty ? UIColor.systemGray3 : UIColor.white).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 120
            for (index, line) in lines.enumerated() {
                let font = UIFont.systemFont(ofSize: index == 0 ? 110 : 64, weight: index == 0 ? .bold : .regular)
                let text = NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: UIColor.black])
                text.draw(at: CGPoint(x: 90, y: y))
                y += font.lineHeight + 28
            }
        }
    }
}

/// În locul `DataScannerViewController` / `VNDocumentCameraViewController` pe simulator.
struct FakeCameraView: View {
    let name: String
    let mode: ScanMode
    let onCode: (String, [CGPoint]) -> Void
    let onPage: (UIImage) -> Void

    var body: some View {
        let sample = FakeScan.sample(named: name)
        GeometryReader { geometry in
            ZStack {
                Color.black
                Image(uiImage: sample.image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
                if mode == .prescription {
                    VStack {
                        Spacer()
                        Button("Folosește pagina") { onPage(sample.image) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.bottom, Spacing.xl * 2)
                            .accessibilityIdentifier("scan.fake.usePage")
                    }
                }
            }
            .task(id: mode) {
                guard mode == .box, let code = sample.datamatrix else { return }
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                let c = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let r: CGFloat = 60
                onCode(code, [
                    CGPoint(x: c.x - r, y: c.y - r), CGPoint(x: c.x + r, y: c.y - r),
                    CGPoint(x: c.x + r, y: c.y + r), CGPoint(x: c.x - r, y: c.y + r),
                ])
            }
        }
        .accessibilityIdentifier("scan.fakeCamera")
    }
}
#endif
