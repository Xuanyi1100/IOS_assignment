// The whole file is conditional so the project still builds if the LiteRT package is not
// added (or cannot be resolved): the app then simply falls back to MockEngine.
#if canImport(LiteRTFoundation)
import Foundation
import LiteRTFoundation
import LiteRTLM

/// Real on-device engine: runs a `.litertlm` model in-process through swift-litert-lm.
///
/// An actor, because the loaded model is shared mutable state that the UI may touch from
/// several tasks (prepare, stream, cancel). The model is loaded once and kept for the
/// lifetime of the app (`shared`) so switching screens never reloads it.
@available(iOS 16, *)
actor LiteRTEngine: InferenceEngine {
    static let shared = LiteRTEngine()

    // First rung of the ladder (plan §3.2): a small model proves the pipeline end to end
    // on a 6 GB phone before we try Gemma 4 E2B.
    private nonisolated static let huggingFaceRepo = "litert-community/Qwen3-0.6B"
    private nonisolated static let fileName = "Qwen3-0.6B.litertlm"

    nonisolated let displayName = NSLocalizedString("engine.litert.name", value: "Qwen3 0.6B (on-device)",
                                                    comment: "Name of the real on-device engine")
    nonisolated var isAvailable: Bool { true }

    private var chat: LiteRTChat?
    private var loadTask: Task<LiteRTChat, Error>?

    // MARK: - InferenceEngine

    func prepare(status: @escaping @Sendable (String) -> Void) async throws {
        _ = try await loadedChat(status: status)
    }

    func generate(prompt: String) async throws -> String {
        var text = ""
        for try await piece in stream(prompt: prompt) { text += piece }
        return text
    }

    nonisolated func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            // Generation runs in its own task; the native runtime does the heavy work off the
            // main thread and we only forward text pieces.
            let task = Task {
                do {
                    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { throw InferenceError.emptyPrompt }
                    let chat = try await self.loadedChat(status: { _ in })
                    // Qwen3 soft switch: asks the model to skip its "thinking" phase. It may still
                    // emit an empty <think></think> pair, so the filter below stays as a safety net.
                    var filter = ThinkTagFilter()
                    #if DEBUG
                    let started = Date()
                    var pieceCount = 0
                    #endif
                    // Qwen3 soft switch: asks the model to skip its reasoning phase, which otherwise
                    // costs 9-14 s before the first visible word. The engine-level thinking flag has
                    // no effect on this model build, so the filter below remains as a safety net.
                    for try await piece in chat.stream(trimmed + " /no_think") {
                        #if DEBUG
                        // Debug builds only: raw model output (escaped, so whitespace is visible) for
                        // diagnosing bad generations from the Xcode console.
                        pieceCount += 1
                        print(String(format: "[LiteRT] +%.2fs piece %d: %@", Date().timeIntervalSince(started),
                                     pieceCount, piece.debugDescription))
                        #endif
                        let visible = filter.feed(piece)
                        if !visible.isEmpty { continuation.yield(visible) }
                    }
                    let tail = filter.finish()
                    if !tail.isEmpty { continuation.yield(tail) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { reason in
                task.cancel()
                // Stop button: also tell the native runtime to stop decoding, otherwise it keeps
                // burning battery after the UI has moved on.
                if case .cancelled = reason {
                    Task { await self.cancelGeneration() }
                }
            }
        }
    }

    // MARK: - Loading

    func cancelGeneration() {
        try? chat?.cancel()
    }

    /// Returns the loaded model, downloading and loading it on first use. Concurrent callers
    /// share one load instead of starting several.
    private func loadedChat(status: @escaping @Sendable (String) -> Void) async throws -> LiteRTChat {
        if let chat { return chat }
        if let loadTask { return try await loadTask.value }

        let task = Task { () throws -> LiteRTChat in
            let downloading = NSLocalizedString("engine.litert.downloading", value: "Downloading model… %d%%",
                                                comment: "Model download progress; %d is a percentage")
            let loading = NSLocalizedString("engine.litert.loading", value: "Loading model…",
                                            comment: "Shown while the model is loaded into memory")
            // Download first (a file already on disk is reused), then load it ourselves: the
            // convenience initializer that downloads by repo name has no way to switch thinking off.
            let destination = try LiteRTChat.defaultStorageDirectory()
                .appendingPathComponent(Self.fileName)
            let remote = URL(string: "https://huggingface.co/\(Self.huggingFaceRepo)/resolve/main/\(Self.fileName)?download=true")!
            try await ModelDownloader.shared.download(from: remote, to: destination, onProgress: { progress in
                status(String(format: downloading, Int(progress.fraction * 100)))
            })
            status(loading)
            return try await LiteRTChat(
                modelFileURL: destination,
                modalities: [],            // text only: smallest memory footprint
                // Qwen3 otherwise "thinks" for a very long time first, which floods the small
                // context window and degrades the answer into garbage.
                thinking: ThinkingConfig(enableThinking: false))
        }
        loadTask = task
        do {
            let loaded = try await task.value
            chat = loaded
            loadTask = nil
            return loaded
        } catch {
            loadTask = nil   // allow a retry after a failed download or load
            throw error
        }
    }
}
#endif
