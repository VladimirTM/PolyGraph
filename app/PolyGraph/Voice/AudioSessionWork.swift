import AVFoundation
import Foundation

/// Configurarea sesiunii audio poate bloca câteva sute de ms (Xcode o marchează „Hang Risk” pe main),
/// așa că o facem pe o coadă serială proprie. Ordinea pe coadă păstrează ordinea apelurilor
/// (o dezactivare nu poate trece înaintea activării care o precede).
nonisolated enum AudioSessionWork {
    private static let queue = DispatchQueue(label: "ro.polygraph.audio-session", qos: .userInitiated)

    /// Pentru voce: `.playback` + `.spokenAudio`; pentru microfon: `.record` + `.measurement`.
    static func activate(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(category, mode: mode, options: [.duckOthers])
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Muzica altor aplicații revine la volum.
    static func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
