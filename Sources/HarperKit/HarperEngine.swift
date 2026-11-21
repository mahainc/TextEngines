import Foundation
import HarperFFI

public struct Lint: Sendable, Equatable, Decodable {
    /// UTF-16 code-unit offsets into the linted text, upper bound exclusive.
    public let utf16Range: Range<Int>
    public let message: String
    public let suggestion: String?

    private enum CodingKeys: String, CodingKey {
        case start, end, message, suggestion
    }

    public init(utf16Range: Range<Int>, message: String, suggestion: String?) {
        self.utf16Range = utf16Range
        self.message = message
        self.suggestion = suggestion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(Int.self, forKey: .start)
        let end = try container.decode(Int.self, forKey: .end)
        guard start <= end else {
            throw DecodingError.dataCorruptedError(forKey: .end, in: container, debugDescription: "end < start")
        }
        utf16Range = start..<end
        message = try container.decode(String.self, forKey: .message)
        suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion)
    }

    public func range(in text: String) -> Range<String.Index>? {
        let utf16 = text.utf16
        guard utf16Range.upperBound <= utf16.count else { return nil }
        let lower = utf16.index(utf16.startIndex, offsetBy: utf16Range.lowerBound)
        let upper = utf16.index(lower, offsetBy: utf16Range.count)
        return lower..<upper
    }
}

public struct HarperEngine: Sendable {
    public init() {}

    public func lints(_ text: String) -> [Lint] {
        guard let json = Self.lintJSON(text) else { return [] }
        return (try? JSONDecoder().decode([Lint].self, from: json)) ?? []
    }

    public func corrected(_ text: String) -> String {
        var output = text
        var nextLintStart = Int.max
        for lint in lints(text).sorted(by: { $0.utf16Range.lowerBound > $1.utf16Range.lowerBound }) {
            guard lint.utf16Range.upperBound <= nextLintStart,
                  let suggestion = lint.suggestion,
                  let range = lint.range(in: output)
            else { continue }
            output.replaceSubrange(range, with: suggestion)
            nextLintStart = lint.utf16Range.lowerBound
        }
        return output
    }

    private static func lintJSON(_ text: String) -> Data? {
        text.withCString { pointer in
            guard let result = harper_lint_json(pointer) else { return nil }
            defer { harper_free_string(result) }
            return Data(bytes: result, count: strlen(result))
        }
    }
}
