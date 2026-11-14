import AVFoundation
import SwiftUI
import UIKit

/// Adăugarea unui medicament prin cameră: cutie (DataMatrix + poza feței) sau rețetă (camera de documente).
/// Se deschide pe tot ecranul; confirmarea e un sheet deasupra lui.
struct ScanView: View {
    /// chemat după ce sheet-ul s-a închis cu cel puțin un medicament salvat
    let onComplete: (ScanOutcome) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pgReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var model = ScanModel()
    @State private var cameraAccess: CameraAccess = .checking
    @State private var pendingOutcome: ScanOutcome?
    /// camera de documente a sistemului, pe tot ecranul (are propriile butoane: X, ✓, declanșator)
    @State private var showsDocumentCamera = false

    private enum CameraAccess {
        case checking, granted, denied
    }

    init(onComplete: @escaping (ScanOutcome) -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZStack {
                    Color.black
                    cameraLayer
                    frozenPhoto
                    codeOutline
                }
                .ignoresSafeArea()

                VStack(spacing: Spacing.m) {
                    guidancePill
                    Spacer()
                    controls
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .pgAnimation(.pgStandard, value: model.guidance)
                .pgAnimation(.pgStandard, value: model.errorMessage)
            }
            .environment(\.colorScheme, .dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Închide") { dismiss() }
                        .accessibilityIdentifier("scan.closeButton")
                }
                ToolbarItem(placement: .principal) {
                    Picker("Ce scanați", selection: $model.mode) {
                        ForEach(ScanMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("scan.modePicker")
                }
            }
        }
        .task { cameraAccess = await Self.requestCameraAccess() }
        .onChange(of: model.mode) {
            model.reset()
            if model.mode == .prescription { openDocumentCameraIfAvailable() }
        }
        .fullScreenCover(isPresented: $showsDocumentCamera) {
            PrescriptionScannerView(
                onScan: { image in
                    showsDocumentCamera = false
                    Task { await model.prescriptionScanned(image, store: store) }
                },
                onCancel: { showsDocumentCamera = false },
                onError: { error in
                    showsDocumentCamera = false
                    model.cameraFailed(error)
                })
            .ignoresSafeArea()
        }
        // conturul verde și haptic-ul pornesc din aceeași stare (DESIGN.md 2.4.5)
        .sensoryFeedback(.impact(weight: .medium), trigger: model.scannedCode) { old, new in
            old == nil && new != nil
        }
        .sensoryFeedback(.error, trigger: model.errorCount)
        .sheet(item: $model.confirmation, onDismiss: confirmationClosed) { confirmation in
            ConfirmSheet(confirmation: confirmation) { outcome in
                pendingOutcome = outcome
                model.confirmation = nil
            }
            .environment(store)
        }
    }

    // MARK: - Camera

    @ViewBuilder
    private var cameraLayer: some View {
        if let fake = fakeCamera {
            fake
        } else {
            switch cameraAccess {
            case .checking:
                Color.black
            case .denied:
                unavailable(
                    "Aplicația nu are acces la cameră",
                    message: "Permiteți accesul din Setări → PolyGraph → Cameră, sau completați medicamentul de mână.",
                    showsSettings: true)
            case .granted:
                switch model.mode {
                case .box:
                    if BoxScannerProxy.isSupported && BoxScannerProxy.isAvailable {
                        BoxScannerView(proxy: model.proxy) { raw, corners in
                            model.codeDetected(raw, corners: corners, store: store)
                        }
                    } else {
                        unavailable(
                            "Camera nu poate citi coduri pe acest telefon",
                            message: "Puteți completa medicamentul de mână.", showsSettings: false)
                    }
                case .prescription:
                    if model.capturedImage == nil {
                        if PrescriptionScannerView.isSupported {
                            prescriptionStart
                        } else {
                            unavailable(
                                "Camera de documente nu e disponibilă",
                                message: "Puteți completa medicamentele de mână.", showsSettings: false)
                        }
                    }
                }
            }
        }
    }

    private var fakeCamera: AnyView? {
        #if DEBUG
        guard let name = model.fakeScan else { return nil }
        if model.mode == .prescription && model.capturedImage != nil { return AnyView(Color.black) }
        return AnyView(FakeCameraView(
            name: name, mode: model.mode,
            onCode: { raw, corners in model.codeDetected(raw, corners: corners, store: store) },
            onPage: { image in Task { await model.prescriptionScanned(image, store: store) } }))
        #else
        return nil
        #endif
    }

    /// Poza trimisă rămâne pe ecran cât se citește, ca omul să vadă ce se analizează.
    @ViewBuilder
    private var frozenPhoto: some View {
        if let image = model.capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .transition(.opacity)
                .accessibilityLabel("Poza trimisă")
        }
    }

    @ViewBuilder
    private var codeOutline: some View {
        if model.scannedCode != nil, model.capturedImage == nil, model.codeCorners.count == 4 {
            Path { path in path.addLines(model.codeCorners); path.closeSubpath() }
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Suprapuneri

    /// Înainte de rețetă: un singur buton mare; camera de documente se deschide singură la alegerea „Rețetă”.
    private var prescriptionStart: some View {
        ContentUnavailableView {
            Label("Fotografiați rețeta", systemImage: "doc.viewfinder")
        } description: {
            Text("Puneți foaia pe o masă, cu lumină bună. Camera o decupează și o îndreaptă singură.")
        } actions: {
            Button("Deschide camera") { showsDocumentCamera = true }
                .buttonStyle(.pgProminent)
                .controlSize(.large)
                .accessibilityIdentifier("scan.openDocumentCamera")
            Button("Completez manual") { model.startManualEntry() }
                .accessibilityIdentifier("scan.unavailable.manualButton")
        }
    }

    private func openDocumentCameraIfAvailable() {
        guard model.fakeScan == nil, cameraAccess == .granted, PrescriptionScannerView.isSupported else { return }
        showsDocumentCamera = true
    }

    /// Pe ecranul de start al rețetei, textul e deja în mijloc; pastila ar fi o dublură.
    private var showsOverlays: Bool {
        !(model.mode == .prescription && model.capturedImage == nil && model.fakeScan == nil
            && cameraAccess == .granted && PrescriptionScannerView.isSupported)
    }

    @ViewBuilder
    private var guidancePill: some View {
        // la eroare, statusul de sus dispare: cardul de jos spune ce s-a întâmplat (Q3-23)
        if showsOverlays, model.errorMessage == nil, let text = model.guidance {
            HStack(spacing: Spacing.xs) {
                if model.isWorking, !isRecognized {
                    ProgressView()
                }
                Text(text)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(.regularMaterial, in: Capsule())
            .id(text)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("scan.guidance")
        }
    }

    private var canShoot: Bool {
        model.fakeScan != nil
            || (cameraAccess == .granted && BoxScannerProxy.isSupported && BoxScannerProxy.isAvailable)
    }

    private var isRecognized: Bool {
        if case .recognized = model.status { true } else { false }
    }

    @ViewBuilder
    private var controls: some View {
        if let message = model.errorMessage {
            errorCard(message)
        } else if showsOverlays, model.mode == .box, !model.isWorking, canShoot {
            VStack(spacing: Spacing.s) {
                Button {
                    Task { await model.capture(store: store) }
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 62, height: 62)
                        Circle().strokeBorder(.white, lineWidth: 4).frame(width: 76, height: 76)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Fotografiază fața cutiei")
                .accessibilityIdentifier("scan.shutter")

                Button("Completez manual") { model.startManualEntry() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("scan.manualButton")
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.body)
                .accessibilityIdentifier("scan.error")
            HStack(spacing: Spacing.s) {
                Button {
                    Task { await model.retry(store: store) }
                } label: {
                    Text("Încearcă din nou").frame(maxWidth: .infinity, minHeight: ControlHeight.caregiver - 16)
                }
                .buttonStyle(.pgProminent)
                .accessibilityIdentifier("scan.retryButton")

                Button {
                    model.startManualEntry()
                } label: {
                    Text("Completez manual").frame(maxWidth: .infinity, minHeight: ControlHeight.caregiver - 16)
                }
                .buttonStyle(.pgProminent)
                .accessibilityIdentifier("scan.manualButton")
            }
        }
        .padding(Spacing.m)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .transition(PgMotion.transition(.move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
    }

    private func unavailable(_ title: String, message: String, showsSettings: Bool) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "camera")
        } description: {
            Text(message)
        } actions: {
            if showsSettings {
                Button("Deschide Setările") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.pgProminent)
            }
            Button("Completez manual") { model.startManualEntry() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("scan.unavailable.manualButton")
        }
        .accessibilityIdentifier("scan.unavailable")
    }

    // MARK: - Închiderea

    private func confirmationClosed() {
        if let outcome = pendingOutcome {
            pendingOutcome = nil
            onComplete(outcome)
            dismiss()
        } else {
            model.reset()
        }
    }

    /// Camera se cere la primul gest care are nevoie de ea: deschiderea acestui ecran.
    private static func requestCameraAccess() async -> CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default: return .denied
        }
    }
}
