import Foundation

/// The single seam between the UI and whatever produces text.
///
/// View controllers only ever talk to this protocol, so swapping the runtime
/// (MockEngine, LiteRT, a GGUF backend...) means writing one new conformance and
/// touching no UI code.
protocol InferenceEngine {
    /// Short human-readable name shown in Settings / About ("Mock", "Gemma 4 E2B"...).
    var displayName: String { get }

    /// Whether this engine can run right now (model present, device capable...).
    var isAvailable: Bool { get }

    /// Returns the complete reply once generation has finished.
    func generate(prompt: String) async throws -> String

    /// Streams the reply piece by piece. Cancelling the consuming task must stop generation.
    func stream(prompt: String) -> AsyncThrowingStream<String, Error>

    /// Gets the engine ready before first use (download weights, load the model).
    /// `status` receives short human-readable progress ("Downloading model… 37%") and may be
    /// called from any thread. Engines with nothing to prepare use the default no-op below.
    func prepare(status: @escaping @Sendable (String) -> Void) async throws
}

extension InferenceEngine {
    func prepare(status: @escaping @Sendable (String) -> Void) async throws {}
}

/// Errors any engine may surface to the UI. Each case carries a message that says
/// what failed and what the user can do next, ready to drop into a UIAlertController.
enum InferenceError: LocalizedError {
    case emptyPrompt
    case engineUnavailable(reason: String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return NSLocalizedString("error.emptyPrompt",
                                     value: "Your message is empty. Type something and try again.",
                                     comment: "Shown when the user sends an empty message")
        case .engineUnavailable(let reason):
            return String(format: NSLocalizedString("error.engineUnavailable",
                                                    value: "The model can't run right now: %@. Switch to the Mock engine in Settings.",
                                                    comment: "Engine cannot run; %@ is the reason"),
                          reason)
        }
    }
}
