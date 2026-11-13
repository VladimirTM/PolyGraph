import SwiftUI

/// „Spuneți-mi cum vă simțiți”: un buton mare, textul care apare pe măsură ce pacientul vorbește,
/// apoi răspunsul serverului, citit cu voce tare. Fără microfon (refuzat / indisponibil): câmp de text.
struct VoiceCheckInView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pgReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var listener = Listener()
    @State private var needsPermission = Listener.needsPermission
    @State private var isSending = false
    @State private var sentText: String?
    @State private var reply: String?
    @State private var sendError: String?
    @State private var typed = ""
    @State private var didGreet = false

    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var smallSize: CGFloat = 17
    private let micSize: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let reply {
                    replyCard(reply)
                        .transition(.opacity)
                } else {
                    micButton
                    statusLine
                    if !listener.transcript.isEmpty {
                        Text(listener.transcript)
                            .font(.system(size: textSize))
                            .foregroundStyle(PgColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("checkin.transcript")
                    }
                    if let sendError {
                        errorBlock(sendError)
                    }
                    if listener.unavailableReason != nil {
                        textFallback
                    }
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity)
        }
        .background(PgColor.background)
        .navigationTitle("Cum vă simțiți")
        .navigationBarTitleDisplayMode(.inline)
        .task { greet() }
        .onDisappear { listener.cancel() }
    }

    // MARK: - Microfonul

    private var isListening: Bool { listener.phase == .listening }

    private var micButton: some View {
        Button(action: micTapped) {
            ZStack {
                // inelul urmează nivelul vocii; cu Reduce Motion rămâne fix
                Circle()
                    .stroke(PgColor.accent.opacity(0.35), lineWidth: 14)
                    .scaleEffect(reduceMotion ? 1.12 : 1.05 + CGFloat(listener.level) * 0.35)
                    .opacity(isListening ? 1 : 0)
                Circle()
                    .fill(PgColor.accent)
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(PgColor.onAccent)
            }
            .frame(width: micSize, height: micSize)
            .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isSending || listener.phase == .finishing)
        .padding(Spacing.xl)
        .accessibilityLabel(isListening ? "Opriți înregistrarea" : "Începeți să vorbiți")
        .accessibilityIdentifier("checkin.micButton")
    }

    private var statusLine: some View {
        Text(status)
            .font(.system(size: textSize, weight: .semibold))
            .foregroundStyle(PgColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("checkin.status")
    }

    private var status: String {
        if isSending || listener.phase == .finishing { return "Am înțeles, mă gândesc…" }
        if isListening { return "Vă ascult…" }
        if listener.unavailableReason != nil { return listener.unavailableReason ?? "" }
        if needsPermission {
            return "Apăsați butonul și spuneți-mi cum vă simțiți. Prima dată, telefonul vă cere voie să folosească microfonul."
        }
        return "Apăsați butonul și spuneți-mi cum vă simțiți."
    }

    private func micTapped() {
        switch listener.phase {
        case .listening:
            listener.stop()
        case .idle, .finished:
            sendError = nil
            Speaker.shared.stop()
            listener.contextualStrings = store.speechHints
            Task {
                await listener.start { text in
                    Task { await send(text) }
                }
                needsPermission = Listener.needsPermission
            }
        case .finishing:
            break
        }
    }

    // MARK: - Trimiterea și răspunsul

    private func send(_ text: String) async {
        guard !text.isEmpty else {
            sendError = "Nu am auzit nimic. Apăsați butonul și mai spuneți o dată."
            listener.reset()
            return
        }
        sentText = text
        sendError = nil
        isSending = true
        defer { isSending = false }
        do {
            let checkIn = try await store.sendCheckIn(text: text)
            withPgAnimation(.pgStandard, reduceMotion: reduceMotion) {
                reply = checkIn.replyText
            }
            Speaker.shared.speak(checkIn.replyText)
        } catch {
            sendError = "Nu am putut trimite. Apăsați „Încercați din nou”."
        }
    }

    private func replyCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(text)
                .font(.system(size: textSize, weight: .semibold))
                .foregroundStyle(PgColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("checkin.reply")
            if let sentText {
                Text("Ați spus: „\(sentText)”")
                    .font(.system(size: smallSize))
                    .foregroundStyle(PgColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SeniorButton("Gata", systemImage: "checkmark", identifier: "checkin.doneButton") {
                dismiss()
            }
            SeniorButton("Mai spun ceva", prominence: .secondary, identifier: "checkin.againButton") {
                startOver()
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.calmCard))
    }

    private func errorBlock(_ message: String) -> some View {
        VStack(spacing: Spacing.s) {
            Text(message)
                .font(.system(size: textSize))
                .foregroundStyle(PgColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("checkin.error")
            if let sentText, !sentText.isEmpty {
                SeniorButton("Încercați din nou", systemImage: "arrow.clockwise", prominence: .secondary,
                             identifier: "checkin.retryButton") {
                    Task { await send(sentText) }
                }
            }
        }
    }

    private var textFallback: some View {
        VStack(spacing: Spacing.s) {
            TextField("Scrieți aici cum vă simțiți", text: $typed, axis: .vertical)
                .font(.system(size: textSize))
                .lineLimit(3...6)
                .padding(Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                        .fill(PgColor.surface))
                .accessibilityIdentifier("checkin.textField")
            SeniorButton("Trimite", systemImage: "paperplane", identifier: "checkin.sendButton") {
                Task { await send(typed.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
    }

    private func greet() {
        guard !didGreet else { return }
        didGreet = true
        Speaker.shared.speak("Cum vă simțiți azi? Apăsați butonul și spuneți-mi.")
    }

    private func startOver() {
        listener.reset()
        Speaker.shared.stop()
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) {
            reply = nil
            sentText = nil
            sendError = nil
            typed = ""
        }
    }
}
