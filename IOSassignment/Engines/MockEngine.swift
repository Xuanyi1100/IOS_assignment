import Foundation

/// Deterministic, rule-based engine that runs anywhere, including the Simulator.
///
/// This is the engine the instructor sees when grading: no download, no device
/// requirement, same answer for the same prompt.
struct MockEngine: InferenceEngine {
    let displayName = NSLocalizedString("engine.mock.name", value: "Mock (offline demo)",
                                        comment: "Name of the built-in fake engine")
    let isAvailable = true

    /// Delay between streamed words so the UI visibly "types".
    private let wordDelayNanoseconds: UInt64 = 60_000_000

    func generate(prompt: String) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InferenceError.emptyPrompt }
        return reply(for: trimmed)
    }

    func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            // Generation runs in its own task, off the main thread.
            let task = Task {
                do {
                    let text = try await generate(prompt: prompt)
                    for word in text.split(separator: " ", omittingEmptySubsequences: false) {
                        // Stop immediately if the consumer cancelled (Stop button).
                        try Task.checkCancellation()
                        continuation.yield(String(word) + " ")
                        try await Task.sleep(nanoseconds: wordDelayNanoseconds)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Tear the generation task down when the stream is cancelled or dropped.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Canned replies

    /// Picks a reply by simple keyword rules so demos look alive but stay predictable.
    private func reply(for prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("hello") || lower.contains("hi") || prompt.contains("你好") {
            return NSLocalizedString("mock.greeting",
                                     value: "Hello! I'm the offline demo engine. Ask me what I am, or how on-device models work.",
                                     comment: "Mock reply to a greeting")
        }
        if lower.contains("who are you") || lower.contains("what are you") {
            return NSLocalizedString("mock.identity",
                                     value: "I'm a stand-in for the real on-device model. In the Simulator I give canned answers; on a physical iPhone the real model replies instead.",
                                     comment: "Mock reply to an identity question")
        }
        if lower.contains("offline") || lower.contains("on-device") || lower.contains("on device") {
            return NSLocalizedString("mock.ondevice",
                                     value: "On-device means the model's weights live on the phone and run in-process. No server, no network, and your text never leaves the device.",
                                     comment: "Mock reply about on-device inference")
        }
        return String(format: NSLocalizedString("mock.default",
                                                value: "(Mock reply) You said: \"%@\". The real model will answer this on a physical device.",
                                                comment: "Fallback mock reply; %@ is the user's prompt"),
                      prompt)
    }
}
