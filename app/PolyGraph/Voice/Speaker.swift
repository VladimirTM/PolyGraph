import AVFoundation
import Foundation

/// Vocea aplicației: româna, rar, peste muzica altor aplicații (pe care o coboară cât vorbește).
final class Speaker {
    static let shared = Speaker()

    /// AVSpeechUtteranceDefaultSpeechRate e 0.5; puțin mai rar se înțelege mai ușor
    static let rate: Float = 0.45

    private let synthesizer = AVSpeechSynthesizer()
    private let releaser = AudioSessionReleaser()
    private lazy var voice: AVSpeechSynthesisVoice? = Self.romanianVoice()

    private init() {
        synthesizer.delegate = releaser
    }

    /// Oprește ce se citea și începe textul nou (vizualul și vocea pornesc din aceeași atingere).
    func speak(_ text: String) {
        guard !text.isEmpty, !Self.isPreview else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Self.rate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Vocea Enhanced / Premium dacă e descărcată în Setări → Accesibilitate → Conținut vorbit.
    static func romanianVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ro-RO" }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "ro-RO")
    }

    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

/// Muzica altor aplicații revine la volum după ce s-a terminat propoziția. Clasa e `nonisolated`
/// pentru că sintetizatorul își cheamă delegatul de pe firul lui, nu de pe main.
private nonisolated final class AudioSessionReleaser: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
