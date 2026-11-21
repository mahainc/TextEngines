import BergamotFFI
import Foundation

public enum BergamotError: Error, Equatable, Sendable {
    case missingModelFile(prefix: String, directory: String)
    case unreadableModelDirectory(directory: String, reason: String)
    case loadFailed(String)
    case translationFailed(String)
}

public actor BergamotEngine {
    private let engine: EngineHandle

    public init(
        modelDirectory: URL,
        threads: Int = 2
    ) throws {
        let files = try ModelFiles(directory: modelDirectory)
        let handle = try Self.call(failingWith: BergamotError.loadFailed) { error in
            bergamot_create(
                files.model.path,
                files.lexicalShortlist.path,
                files.vocabulary.path,
                Int32(threads),
                &error
            )
        }
        engine = EngineHandle(handle)
    }

    public func translate(_ text: String) throws -> String {
        let translated = try Self.call(failingWith: BergamotError.translationFailed) { error in
            bergamot_translate(engine.pointer, text, &error)
        }
        return Self.consume(translated) ?? ""
    }

    /// Runs an FFI call that returns nil and sets its error string on failure.
    private static func call<Result>(
        failingWith failure: (String) -> BergamotError,
        _ body: (inout UnsafeMutablePointer<CChar>?) -> Result?
    ) throws -> Result {
        var error: UnsafeMutablePointer<CChar>?
        guard let result = body(&error) else {
            throw failure(consume(error) ?? "unknown error")
        }
        return result
    }

    private static func consume(_ string: UnsafeMutablePointer<CChar>?) -> String? {
        guard let string else { return nil }
        defer { bergamot_free_string(string) }
        return String(cString: string)
    }
}

// Unchecked: the pointer is only dereferenced from the owning actor, and destroyed once in deinit.
private final class EngineHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        bergamot_destroy(pointer)
    }
}

private struct ModelFiles {
    let model: URL
    let lexicalShortlist: URL
    let vocabulary: URL

    init(directory: URL) throws {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        } catch {
            throw BergamotError.unreadableModelDirectory(directory: directory.path, reason: error.localizedDescription)
        }
        func file(_ prefix: String) throws -> URL {
            guard let name = names.sorted().first(where: { $0.hasPrefix(prefix) }) else {
                throw BergamotError.missingModelFile(prefix: prefix, directory: directory.path)
            }
            return directory.appendingPathComponent(name)
        }
        model = try file("model.")
        lexicalShortlist = try file("lex.")
        vocabulary = try file("vocab.")
    }
}
