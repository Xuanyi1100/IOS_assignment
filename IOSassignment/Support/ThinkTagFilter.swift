import Foundation

/// Removes `<think>…</think>` reasoning blocks from a streamed model reply.
///
/// Some models (e.g. Qwen3) "think aloud" before answering. That text is not part of the answer
/// and would otherwise fill the screen. Replies arrive in arbitrary chunks, so a tag can be
/// split across two chunks (`"<thi"` + `"nk>"`); the filter holds back any tail that might be
/// the start of a tag until it knows.
///
/// Members are `nonisolated`: this is pure text processing that runs on the inference task, not
/// the main thread, so it must not be tied to the main actor.
struct ThinkTagFilter {
    private nonisolated static let open = "<think>"
    private nonisolated static let close = "</think>"

    private var pending = ""
    private var insideThink = false
    /// Whitespace between the closing tag and the answer is dropped until real text arrives.
    private var sawVisibleText = false

    nonisolated init() {}

    /// Feeds one streamed chunk and returns the text that is safe to show now (maybe empty).
    nonisolated mutating func feed(_ chunk: String) -> String {
        pending += chunk
        var output = ""
        while true {
            if insideThink {
                if let end = pending.range(of: Self.close) {
                    pending = String(pending[end.upperBound...])
                    insideThink = false
                } else {
                    // Still thinking: discard everything except a possible partial "</think>".
                    pending = String(pending.suffix(Self.partialSuffixLength(of: pending, tag: Self.close)))
                    break
                }
            } else if let start = pending.range(of: Self.open) {
                output += pending[..<start.lowerBound]
                pending = String(pending[start.upperBound...])
                insideThink = true
            } else {
                // No tag yet: emit all except a tail that could be the beginning of "<think>".
                let hold = Self.partialSuffixLength(of: pending, tag: Self.open)
                output += pending.dropLast(hold)
                pending = String(pending.suffix(hold))
                break
            }
        }
        return trimLeadingWhitespace(output)
    }

    /// Call when the stream ends: releases any held-back text that turned out not to be a tag.
    nonisolated mutating func finish() -> String {
        defer { pending = "" }
        return insideThink ? "" : trimLeadingWhitespace(pending)
    }

    private nonisolated mutating func trimLeadingWhitespace(_ text: String) -> String {
        guard !sawVisibleText else { return text }
        let trimmed = String(text.drop(while: { $0.isWhitespace }))
        if !trimmed.isEmpty { sawVisibleText = true }
        return trimmed
    }

    /// Length of the longest suffix of `text` that is a proper prefix of `tag`.
    private nonisolated static func partialSuffixLength(of text: String, tag: String) -> Int {
        let maxLength = min(text.count, tag.count - 1)
        guard maxLength > 0 else { return 0 }
        for length in stride(from: maxLength, through: 1, by: -1) where text.hasSuffix(tag.prefix(length)) {
            return length
        }
        return 0
    }
}
