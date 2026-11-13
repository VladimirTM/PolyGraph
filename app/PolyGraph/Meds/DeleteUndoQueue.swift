import Foundation
import Observation

/// Ștergerea cu „Anulează” (agency, fără dialog): medicamentul dispare imediat din listă, iar DELETE
/// pleacă abia după `delay`. „Anulează” în fereastra asta îl readuce și nu trimite nimic.
@Observable
final class DeleteUndoQueue {
    static let undoWindow: Duration = .seconds(5)

    struct Pending: Equatable {
        let id: String
        /// „Sintrom 4 mg”, pentru bannerul „Am șters …”
        let name: String
    }

    /// ștergerea care încă se poate anula
    private(set) var pending: Pending?
    /// medicamentele ascunse din listă: în fereastra de anulare și cât timp pleacă DELETE
    private(set) var hiddenIDs: Set<String> = []
    /// eroarea ultimului DELETE; medicamentul reapare în listă
    var lastError: String?

    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private let perform: (String) async throws -> Void
    @ObservationIgnored private var timer: Task<Void, Never>?

    init(delay: Duration = DeleteUndoQueue.undoWindow, perform: @escaping (String) async throws -> Void = { _ in }) {
        self.delay = delay
        self.perform = perform
    }

    func schedule(id: String, name: String) {
        // o a doua ștergere o confirmă pe prima: bannerul arată mereu doar ultima
        if let previous = pending, previous.id != id {
            timer?.cancel()
            Task { await commit(previous.id) }
        }
        withPgAnimation(.pgStandard) {
            hiddenIDs.insert(id)
            pending = Pending(id: id, name: name)
        }
        timer = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.commit(id)
        }
    }

    func undo() {
        timer?.cancel()
        timer = nil
        guard let pending else { return }
        withPgAnimation(.pgStandard) {
            hiddenIDs.remove(pending.id)
            self.pending = nil
        }
    }

    /// La deconectare: nimic nu mai pleacă spre server.
    func cancelAll() {
        timer?.cancel()
        timer = nil
        pending = nil
        hiddenIDs = []
    }

    private func commit(_ id: String) async {
        if pending?.id == id {
            withPgAnimation(.pgStandard) { pending = nil }
            timer = nil
        }
        do {
            try await perform(id)
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "Nu am putut șterge medicamentul."
        }
        withPgAnimation(.pgStandard) { _ = hiddenIDs.remove(id) }
    }
}
