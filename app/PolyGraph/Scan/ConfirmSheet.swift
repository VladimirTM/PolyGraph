import SwiftUI
import UIKit

/// Confirmarea după scanare: un `Form` de sistem per candidat; rețeta cu mai multe medicamente
/// devine pași („1 din 3”) în același sheet. Nimic nu se salvează fără „Salvează”.
struct ConfirmSheet: View {
    let confirmation: ScanConfirmation
    /// setat când se editează un medicament deja salvat (A3): „Salvează” trimite PATCH, nu POST
    let editingID: String?
    /// `nil` = închis fără să se salveze nimic
    let onFinish: (ScanOutcome?) -> Void

    @Environment(AppStore.self) private var store

    @State private var drafts: [MedDraft]
    @State private var page = 0
    @State private var done: Set<String> = []
    @State private var savedCount = 0
    @State private var newAlerts = 0
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var errorCount = 0
    @State private var confirmDiscard = false

    @MainActor
    init(confirmation: ScanConfirmation, editingID: String? = nil, onFinish: @escaping (ScanOutcome?) -> Void) {
        self.confirmation = confirmation
        self.editingID = editingID
        self.onFinish = onFinish
        _drafts = State(initialValue: confirmation.result.candidates.map(MedDraft.init))
    }

    private var isMultiStep: Bool { drafts.count > 1 }

    private var current: MedDraft? {
        drafts.indices.contains(page) ? drafts[page] : nil
    }

    private var hasEdits: Bool {
        drafts.contains { $0.hasEdits }
    }

    var body: some View {
        NavigationStack {
            pages
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .safeAreaInset(edge: .bottom) { bottomBar }
                .confirmationDialog(
                    "Renunțați la modificări?", isPresented: $confirmDiscard, titleVisibility: .visible
                ) {
                    Button("Renunță la modificări", role: .destructive) { finish() }
                        .accessibilityIdentifier("confirm.discardButton")
                }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(hasEdits || savedCount > 0 || isSaving)
        .sensoryFeedback(.error, trigger: errorCount)
    }

    private var title: String {
        if isMultiStep { return "\(page + 1) din \(drafts.count)" }
        if editingID != nil { return "Editează" }
        return current?.displayName ?? "Medicament nou"
    }

    @ViewBuilder
    private var pages: some View {
        if isMultiStep {
            TabView(selection: $page) {
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    form(for: draft, showsHeader: true)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else if let draft = drafts.first {
            form(for: draft, showsHeader: false)
        }
    }

    private func form(for draft: MedDraft, showsHeader: Bool) -> some View {
        DraftForm(
            draft: draft,
            photo: confirmation.photo,
            photoURL: store.api.mediaURL(draft.original.photourl),
            warnings: confirmation.result.warnings,
            showsHeader: showsHeader,
            isDone: done.contains(draft.id))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(savedCount > 0 ? "Gata" : "Renunță") {
                if hasEdits && savedCount == 0 { confirmDiscard = true } else { finish() }
            }
            .disabled(isSaving)
            .accessibilityIdentifier("confirm.cancelButton")
        }
        #if DEBUG
        ToolbarItem(placement: .topBarTrailing) {
            OCRExportButton(confirmation: confirmation)
        }
        #endif
    }

    // MARK: - Bara de jos

    private var bottomBar: some View {
        VStack(spacing: Spacing.xs) {
            if let draft = current, !done.contains(draft.id) {
                // avertizarea vine înainte de salvare, nu după (skill §16)
                if draft.isExpired(on: store.clock.now), let expiry = draft.expiry {
                    Label(
                        "Cutia pare expirată (\(expiry.formatted(.dateTime.day().month(.wide).year().locale(PgFormat.romanian)))). Verificați data înainte de salvare.",
                        systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("confirm.expiredWarning")
                }
                if let existing = draft.duplicate(in: store.meds, excluding: editingID) {
                    Label(
                        "\(existing.displayName) e deja în listă. Verificați să nu-l adăugați de două ori.",
                        systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("confirm.duplicateWarning")
                }
                if !draft.canSave {
                    Text("Scrieți numele medicamentului.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("confirm.error")
            }

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if isSaving { ProgressView() }
                    Text(saveTitle)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: ControlHeight.caregiver)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || current.map { !$0.canSave || done.contains($0.id) } ?? true)
            .accessibilityIdentifier("confirm.saveButton")

            if isMultiStep, let draft = current, !done.contains(draft.id) {
                Button("Sari peste acesta") { skip(draft) }
                    .disabled(isSaving)
                    .accessibilityIdentifier("confirm.skipButton")
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(.bar)
    }

    private var saveTitle: String {
        guard let draft = current else { return "Salvează" }
        if done.contains(draft.id) { return "Salvat" }
        return isSaving ? "Se salvează…" : "Salvează"
    }

    // MARK: - Acțiuni

    private func save() async {
        guard let draft = current, draft.canSave, !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            if let editingID {
                let item = draft.item()
                try await store.updateMed(
                    id: editingID,
                    MedicationUpdate(
                        product: item.product, substances: item.substances, dosage: item.dosage,
                        prescriber: item.prescriber))
            } else {
                newAlerts += try await store.addMed(draft.item())
            }
            savedCount += 1
            done.insert(draft.id)
            advance()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încercați din nou."
            errorCount += 1
        }
    }

    private func skip(_ draft: MedDraft) {
        done.insert(draft.id)
        advance()
    }

    /// Următorul medicament nesalvat; după ultimul, sheet-ul se închide.
    private func advance() {
        if let next = drafts.indices.first(where: { !done.contains(drafts[$0].id) }) {
            withPgAnimation(.pgStandard) { page = next }
        } else {
            finish()
        }
    }

    private func finish() {
        onFinish(savedCount > 0 ? ScanOutcome(savedCount: savedCount, newAlerts: newAlerts) : nil)
    }
}

// MARK: - Formularul unui medicament

private struct DraftForm: View {
    @Bindable var draft: MedDraft
    let photo: UIImage?
    let photoURL: URL?
    let warnings: [String]
    let showsHeader: Bool
    let isDone: Bool

    var body: some View {
        Form {
            photoSection

            if showsHeader {
                Section {
                    Text(draft.displayName)
                        .font(.title2.weight(.semibold))
                    if isDone {
                        Label("Gata", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(PgColor.accent)
                    }
                }
            }

            if !warnings.isEmpty {
                Section {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.circle")
                    }
                }
                .accessibilityIdentifier("confirm.warnings")
            }

            productSection
            dosageSection
            prescriberSection
            expirySection
        }
        .disabled(isDone)
    }

    @ViewBuilder
    private var photoSection: some View {
        if photo != nil || photoURL != nil {
            Section {
                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                    } else if let photoURL {
                        AsyncImage(url: photoURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityLabel("Poza cutiei")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var productSection: some View {
        Section {
            TextField("Nume (ex. Sintrom)", text: $draft.brand)
                .textInputAutocapitalization(.words)
                .reviewHighlight(draft.needsReview(.product))
                .accessibilityLabel("Numele medicamentului")
                .accessibilityIdentifier("confirm.brandField")
            TextField("Concentrație (ex. 4 mg)", text: $draft.strengthText)
                .reviewHighlight(draft.needsReview(.product))
                .accessibilityLabel("Concentrația")
                .accessibilityIdentifier("confirm.strengthField")

            if draft.substances.isEmpty {
                Text("Substanța activă nu a fost găsită")
                    .foregroundStyle(.secondary)
                    .reviewHighlight(draft.needsReview(.substances))
                    .accessibilityIdentifier("confirm.substance.missing")
            } else {
                ForEach(Array(draft.substances.enumerated()), id: \.offset) { index, substance in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(substance.displayName ?? "Substanță necunoscută")
                        Text(substance.atc.map { "ATC \($0)" } ?? "fără cod ATC")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .reviewHighlight(draft.needsReview(.substances))
                    .accessibilityIdentifier("confirm.substance.\(index)")
                }
            }

            NavigationLink {
                KBSearchView(draft: draft)
            } label: {
                Label(
                    draft.substances.isEmpty ? "Caută substanța în catalog" : "Alt medicament? Caută în catalog",
                    systemImage: "magnifyingglass")
            }
            .accessibilityIdentifier("confirm.searchCatalog")
        } header: {
            ReviewHeader(
                title: "Medicamentul",
                flagged: draft.needsReview(.product) || draft.needsReview(.substances))
        }
    }

    private var dosageSection: some View {
        Section {
            doseStepper("Dimineața", value: $draft.morning, id: "morning")
            doseStepper("Prânz", value: $draft.noon, id: "noon")
            doseStepper("Seara", value: $draft.evening, id: "evening")
            doseStepper("Culcare", value: $draft.bedtime, id: "bedtime")
            Toggle("Doar la nevoie", isOn: $draft.asNeeded)
                .accessibilityIdentifier("confirm.asNeededToggle")
            Picker("Masa", selection: $draft.withFood) {
                ForEach(draft.foodChoices, id: \.self) { choice in
                    Text(choice.shortLabel).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("confirm.foodPicker")
        } header: {
            ReviewHeader(title: "Când se ia (pastile)", flagged: draft.needsReview(.dosage))
        } footer: {
            if let raw = draft.original.dosage.raw, !raw.isEmpty {
                Text("Pe rețetă: „\(raw)”")
            }
        }
    }

    private func doseStepper(_ label: String, value: Binding<Double>, id: String) -> some View {
        Stepper(value: value, in: 0...4, step: 0.5) {
            HStack {
                Text(label)
                Spacer()
                Text(PgFormat.doseAmount(value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(value.wrappedValue == 0 ? .secondary : .primary)
            }
        }
        .reviewHighlight(draft.needsReview(.dosage))
        .accessibilityValue(PgFormat.doseAmount(value.wrappedValue))
        .accessibilityIdentifier("confirm.dose.\(id)")
    }

    private var prescriberSection: some View {
        Section("Medicul") {
            TextField("Numele medicului", text: $draft.prescriberName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("confirm.prescriberField")
            TextField("Specialitatea (ex. cardiologie)", text: $draft.specialty)
                .accessibilityIdentifier("confirm.specialtyField")
        }
    }

    private var expirySection: some View {
        Section {
            if draft.expiry != nil {
                DatePicker(
                    "Expiră la",
                    selection: Binding(get: { draft.expiry ?? Date() }, set: { draft.expiry = $0 }),
                    displayedComponents: .date)
                    .environment(\.locale, PgFormat.romanian)
                    .accessibilityIdentifier("confirm.expiryPicker")
            } else {
                Button("Adaugă data de expirare") { draft.expiry = Date() }
                    .accessibilityIdentifier("confirm.addExpiryButton")
            }
        } header: {
            Text("Cutia")
        } footer: {
            if let batch = draft.original.product.batch {
                Text("Lot \(batch)")
            }
        }
    }
}

/// Antetul unei secțiuni, cu „verificați” când serverul nu e sigur de câmpurile din ea.
private struct ReviewHeader: View {
    let title: String
    let flagged: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if flagged {
                Label("verificați", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.orange)
                    .textCase(nil)
                    .accessibilityIdentifier("confirm.reviewBadge")
            }
        }
    }
}

private extension View {
    /// Fundalul galben deschis al câmpurilor nesigure.
    func reviewHighlight(_ flagged: Bool) -> some View {
        listRowBackground(flagged ? PgColor.review : nil)
    }
}

// MARK: - Căutarea în catalog

/// Substanță negăsită sau medicament greșit: căutare în /v1/kb/search, alegerea înlocuiește identificarea.
private struct KBSearchView: View {
    @Bindable var draft: MedDraft
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var hits: [KBSearchHit] = []
    @State private var isSearching = false
    @State private var error: String?

    var body: some View {
        List {
            ForEach(Array(hits.enumerated()), id: \.offset) { index, hit in
                Button {
                    draft.apply(hit)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text([hit.brand, hit.strengthText].compactMap { $0 }.joined(separator: " "))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text([hit.substances.displayNames, hit.form ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("kbsearch.result.\(index)")
            }
        }
        .overlay {
            if let error {
                ContentUnavailableView("Căutarea nu a mers", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if hits.isEmpty && !isSearching {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    ContentUnavailableView(
                        "Căutați în catalog", systemImage: "magnifyingglass",
                        description: Text("Scrieți numele de pe cutie sau substanța activă."))
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Nume sau substanță")
        .navigationTitle("Caută în catalog")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if query.isEmpty { query = draft.brand }
        }
        .task(id: query) {
            await search()
        }
        .accessibilityIdentifier("kbsearch.list")
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            hits = []
            error = nil
            return
        }
        // pauză scurtă între taste, ca să nu se trimită o cerere la fiecare literă
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let result = try await store.api.kbSearch(text)
            guard !Task.isCancelled else { return }
            hits = result.results
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            self.error = (error as? LocalizedError)?.errorDescription
        }
    }
}

// MARK: - Exportul OCR (doar Debug)

#if DEBUG
/// „Salvează OCR”: liniile citite de telefon, pentru `demo/ocr/<nume>.json` (date reale pentru testele B3).
private struct OCRExportButton: View {
    let confirmation: ScanConfirmation
    @State private var sharedFile: SharedFile?

    var body: some View {
        if !confirmation.ocrLines.isEmpty {
            Button {
                sharedFile = exportURL.map(SharedFile.init)
            } label: {
                Label("Salvează OCR", systemImage: "doc.text.magnifyingglass")
            }
            .accessibilityIdentifier("confirm.exportOCRButton")
            .sheet(item: $sharedFile) { file in
                ActivitySheet(items: [file.url])
            }
        }
    }

    private var exportURL: URL? {
        guard !confirmation.ocrLines.isEmpty else { return nil }
        let brand = confirmation.result.candidates.first?.product.brand ?? "scan"
        let slug = brand.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: PgFormat.romanian)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        // ora în nume: două scanări ale aceleiași cutii nu se mai suprapun în demo/ocr/
        let noCode = confirmation.kind == .box && confirmation.datamatrix == nil ? "_fara_cod" : ""
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let time = String(format: "%02ld%02ld%02ld", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        let name = "\(slug.isEmpty ? "scan" : slug)_\(confirmation.kind.rawValue)\(noCode)_\(time).json"
        let export = OCRExport(
            kind: confirmation.kind.rawValue, datamatrix: confirmation.datamatrix, ocrLines: confirmation.ocrLines)
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(export), (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}

private struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Foaia de partajare a sistemului („Salvează în Fișiere”, AirDrop pe Mac).
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct OCRExport: Encodable {
    let kind: String
    let datamatrix: String?
    let ocrLines: [OCRLine]

    enum CodingKeys: String, CodingKey {
        case kind, datamatrix
        case ocrLines = "ocr_lines"
    }
}
#endif
