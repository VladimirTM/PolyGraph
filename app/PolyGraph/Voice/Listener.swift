import AVFoundation
import Foundation
import Observation
import Speech

/// Microfonul modului senior: transcriere pe telefon, în română, cu textul parțial pe măsură ce
/// vorbește pacientul și nivelul vocii pentru inel. Pornește la atingere și se oprește la atingere,
/// după liniște (`SilenceDetector`) sau la 60 s.
@Observable
final class Listener {
    enum Phase: Equatable {
        case idle
        case listening
        /// microfonul e oprit, se așteaptă textul final
        case finishing
        case finished
    }

    private(set) var phase: Phase = .idle
    private(set) var transcript = ""
    /// nivelul netezit 0…1, pentru inel
    private(set) var level: Float = 0
    /// de ce nu se poate vorbi (permisiune refuzată, recunoaștere indisponibilă): ecranul trece pe text
    private(set) var unavailableReason: String?
    /// numele medicamentelor, ca recunoașterea să scrie „Sintrom”, nu „sindrom”
    var contextualStrings: [String] = []

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ro-RO"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var detector = SilenceDetector()
    @ObservationIgnored private var rawLevel: Float = 0
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var finishTimer: Task<Void, Never>?
    @ObservationIgnored private var onFinish: ((String) -> Void)?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var tapInstalled = false

    /// Încă n-am cerut voie pentru microfon sau pentru recunoașterea vocală.
    static var needsPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .notDetermined
            || AVAudioApplication.shared.recordPermission == .undetermined
    }

    private static var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Cele mai vândute ~100 de branduri din catalog (`brands.txt`, primele rânduri).
    static let commonBrands: [String] = {
        guard let url = Bundle.main.url(forResource: "brands", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        return Array(lines.filter { !$0.isEmpty }.prefix(100))
    }()

    // MARK: - Pornire și oprire

    /// Cere permisiunile la prima folosire, apoi pornește. `onFinish` primește transcrierea finală.
    func start(onFinish: @escaping (String) -> Void) async {
        guard !isStarting, phase == .idle || phase == .finished else { return }
        isStarting = true
        defer { isStarting = false }
        self.onFinish = onFinish
        if let fake = DebugEnvironment.current.fakeTranscript {
            simulate(fake)
            return
        }
        guard await SpeechBridge.authorize() else {
            unavailableReason = "Nu am voie să folosesc microfonul. Puteți scrie mai jos."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            unavailableReason = "Recunoașterea vocală nu merge acum. Puteți scrie mai jos."
            return
        }
        do {
            try begin(with: recognizer)
        } catch {
            teardown()
            phase = .idle
            unavailableReason = "Microfonul nu pornește. Puteți scrie mai jos."
        }
    }

    /// A doua atingere, liniștea sau limita de timp.
    func stop() {
        guard phase == .listening else { return }
        phase = .finishing
        ticker?.cancel()
        ticker = nil
        stopAudio()
        request?.endAudio()
        withPgAnimation(.pgQuick) { level = 0 }
        // textul final vine de obicei în câteva sute de ms; dacă nu, trimitem ce avem
        finishTimer = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// La ieșirea din ecran: totul se oprește și nu se trimite nimic.
    func cancel() {
        onFinish = nil
        teardown()
        phase = .idle
    }

    /// „Mai spun ceva”: ecranul o ia de la capăt.
    func reset() {
        cancel()
        transcript = ""
        level = 0
    }

    // MARK: - Intern

    private func begin(with recognizer: SFSpeechRecognizer) throws {
        Speaker.shared.stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.contextualStrings = contextualStrings
        self.request = request

        // `owner` e o constantă: închiderile de mai jos rulează pe firele audio / de recunoaștere
        // și sar înapoi pe main; legătura se rupe în `teardown()`
        let owner = self
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(
            onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0),
            block: SpeechBridge.tap(request: request) { value in
                Task { @MainActor in owner.receive(level: value) }
            })
        tapInstalled = true
        engine.prepare()
        try engine.start()

        task = SpeechBridge.recognize(recognizer, request: request) { text, isFinal, failed in
            Task { @MainActor in owner.receive(text: text, isFinal: isFinal, failed: failed) }
        }

        transcript = ""
        rawLevel = 0
        level = 0
        detector = SilenceDetector()
        unavailableReason = nil
        phase = .listening
        startTicker()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.phase == .listening else { return }
                if self.detector.feed(level: self.rawLevel, at: Self.uptime) != .listen {
                    self.stop()
                    return
                }
            }
        }
    }

    private func receive(level value: Float) {
        guard phase == .listening else { return }
        rawLevel = value
        let smoothed = level * 0.7 + value * 0.3
        withPgAnimation(.pgQuick) { level = smoothed }
    }

    private func receive(text: String?, isFinal: Bool, failed: Bool) {
        if let text, !text.isEmpty, phase == .listening || phase == .finishing {
            transcript = text
            if phase == .listening { detector.noteWords(at: Self.uptime) }
        }
        if phase == .finishing && (isFinal || failed) {
            finish()
        } else if phase == .listening && (isFinal || failed) {
            // recunoașterea s-a oprit singură (de exemplu, n-a auzit nimic mult timp)
            stop()
        }
    }

    private func finish() {
        guard phase == .finishing else { return }
        teardown()
        phase = .finished
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let callback = onFinish
        onFinish = nil
        callback?(text)
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func teardown() {
        ticker?.cancel()
        ticker = nil
        finishTimer?.cancel()
        finishTimer = nil
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// `PG_FAKE_TRANSCRIPT` (Debug): textul apare cuvânt cu cuvânt, apoi „liniștea” oprește singură.
    private func simulate(_ text: String) {
        let words = text.split(separator: " ").map(String.init)
        transcript = ""
        unavailableReason = nil
        phase = .listening
        ticker = Task { [weak self] in
            for index in words.indices {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.phase == .listening else { return }
                self.transcript = words[...index].joined(separator: " ")
                let value = Float.random(in: 0.3...0.8)
                withPgAnimation(.pgQuick) { self.level = value }
            }
            try? await Task.sleep(for: .seconds(2))
            guard let owner = self, owner.phase == .listening else { return }
            owner.phase = .finishing
            withPgAnimation(.pgQuick) { owner.level = 0 }
            owner.finish()
        }
    }
}

/// Punțile spre AVAudioEngine și Speech: închiderile create aici nu sunt legate de main actor,
/// pentru că sistemul le cheamă de pe firele lui.
private nonisolated enum SpeechBridge {
    static func authorize() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    static func tap(
        request: SFSpeechAudioBufferRecognitionRequest, onLevel: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            onLevel(SpeechBridge.level(of: buffer))
        }
    }

    static func recognize(
        _ recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
        onResult: @escaping @Sendable (String?, Bool, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onResult(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }

    /// RMS → dB → 0…1 (−50 dB = 0, 0 dB = 1)
    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(count)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_001))
        return min(max((decibels + 50) / 50, 0), 1)
    }
}
