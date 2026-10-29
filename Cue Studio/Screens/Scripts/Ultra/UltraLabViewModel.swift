#if DEBUG
import Foundation

@MainActor
@Observable
final class UltraLabViewModel {
    var prompt = ""
    var consents = false
    private(set) var result = ""
    private(set) var draft = ""
    private(set) var isWorking = false
    private(set) var status = ""
    private var task: Task<Void, Never>?
    private let service = UltraLabService()

    func generate(_ request: ScriptRequest) {
        guard consents, !isWorking else { return }
        isWorking = true
        result = ""
        draft = ""
        task = Task {
            defer { isWorking = false; task = nil }
            do {
                let text = try await service.generate(context: UltraLabPrompt.context(request), consent: consents) { status = $0 }
                try Task.checkCancellation()
                guard consents else { return }
                result = text
                status = "Ready"
            } catch {
                draft = service.draft
                status = "Failed or cancelled. Draft is not a completed Ultra script."
            }
        }
    }

    func revoke() {
        consents = false
        task?.cancel()
        result = ""
        draft = ""
        status = ""
    }
}
#endif
