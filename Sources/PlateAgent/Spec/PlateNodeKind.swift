import Foundation

/// What a box is: a part of the system (a service, a type, a module), an agent's run, or something across a wire.
public enum PlateNodeKind: String, Codable, Sendable, CaseIterable {
    /// A solid card with a colour bar: its name, one sentence of what it is responsible for, a code line.
    case service
    /// A dashed gold box: something that runs on a model, or any run that streams and writes back.
    case agent
    /// A dashed box: a process across a wire, a store, a framework the system calls.
    case external

    /// A kind a model named loosely; an unknown kind is a service.
    public init(loose name: String) {
        let word = name.lowercased().trimmingCharacters(in: .whitespaces)
        if let kind = PlateNodeKind(rawValue: word) { self = kind; return }
        switch word {
        case "ext", "outside", "process", "wire", "store", "database", "db", "framework", "external service", "dependency": self = .external
        case "run", "model", "llm", "worker", "job": self = .agent
        default: self = .service
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(loose: (try? decoder.singleValueContainer().decode(String.self)) ?? "")
    }
}
