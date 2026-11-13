import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Codul QR al linkului de partajare, generat pe telefon (CoreImage, fără dependențe).
enum QRCode {
    /// Un pixel pe modul; view-ul îl mărește fără interpolare, ca marginile să rămână nete.
    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
