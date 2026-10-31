import Foundation

/// What the sources are, read off the code rather than guessed, for the model to draw from: the parts (a folder named
/// for the type it declares, or a file's own type), who refers to whom among them and through what, the operations and
/// agents each declares, what starts them from outside the sources, and what they import. Ranked: a part that refers
/// to others sits above them, so the lanes can follow the call depth.
///
/// PIN: facts, never a layout. The model still decides what the plate says; it decides it from what the code shows.
struct PlateGraph: Sendable {
    struct Part: Sendable, Equatable {
        let name: String
        /// The folder, or the file, relative to the project.
        let path: String
        var what: String?
        var operations: [String] = []
        var agents: [String] = []
        var rank = 0
        /// Not under the sources: a neighbour of the same kind the parts refer to (a service in another target).
        var beside = false
    }

    struct Reference: Sendable, Equatable {
        let from: String
        let to: String
        let count: Int
        let example: String
    }

    struct Starter: Sendable, Equatable {
        let name: String
        let path: String
        let parts: [String]
    }

    var parts: [Part] = []
    var references: [Reference] = []
    var starters: [Starter] = []
    var imports: [(name: String, count: Int)] = []

    static let skipped: Set<String> = [".build", "node_modules", "DerivedData", "Pods", "dist", "build", ".next", "vendor", "__pycache__", ".git",
                                       ".swiftpm", "Tests", "tests", "test", "__tests__", "Evals", "evals", "fixtures"]
    private static let common: Set<String> = ["Foundation", "SwiftUI", "AppKit", "UIKit", "Combine", "os", "Dispatch", "XCTest", "CoreGraphics",
                                              "ImageIO", "UniformTypeIdentifiers", "Darwin", "Observation", "Testing"]

    // MARK: Reading

    /// The graph of the code files under `sources`, with what starts them found anywhere else under `root`.
    static func read(_ sources: [URL], root: URL, maxScan: Int = 3_000) -> PlateGraph {
        let sourceFiles = sources.flatMap { codeFiles(under: $0) }
        guard !sourceFiles.isEmpty else { return PlateGraph() }
        let languages = Set(sourceFiles.map { $0.pathExtension.lowercased() })
        // The project in the sources' languages, read once: for the neighbours and for what starts the parts.
        var texts: [URL: String] = [:]
        for file in sourceFiles { texts[file] = try? String(contentsOf: file, encoding: .utf8) }
        let inSources = Set(sourceFiles)
        for file in codeFiles(under: root).prefix(maxScan) where !inSources.contains(file) && languages.contains(file.pathExtension.lowercased()) {
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 300_000 else { continue }
            texts[file] = try? String(contentsOf: file, encoding: .utf8)
        }
        let files = Array(texts.keys)
        let declared = texts.mapValues(declaredTypes)
        // The types declared by the files directly in each folder.
        var direct: [String: Set<String>] = [:]
        for (file, types) in declared { direct[file.deletingLastPathComponent().path, default: []].formUnion(types) }
        // Each file's part: the outermost folder named for a type a file directly in it declares (`SessionService/
        // SessionService.swift`: a service's folder, not the folder of a model inside it, never a whole target), else
        // the file's own first type.
        var partOf: [URL: (name: String, path: URL)] = [:]
        for file in files {
            var folder = file.deletingLastPathComponent()
            var found: (String, URL)?
            while folder.path.hasPrefix(root.path), folder.path != root.path {
                if direct[folder.path]?.contains(folder.lastPathComponent) == true { found = (folder.lastPathComponent, folder) }
                folder = folder.deletingLastPathComponent()
            }
            if let found { partOf[file] = found } else if inSources.contains(file), let first = declared[file]?.first { partOf[file] = (first, file) }
        }
        // The parts are the sources'; a part elsewhere joins them as a neighbour when it is of their kind (the suffix
        // most of them share: Service, Store, Controller) and they refer to it.
        let own = Set(partOf.filter { inSources.contains($0.key) }.map(\.value.name))
        let kind = dominantSuffix(Array(own))
        var neighbours: Set<String> = []
        if let kind {
            let outside = Set(partOf.filter { !inSources.contains($0.key) }.map(\.value.name)).subtracting(own).filter { $0.hasSuffix(kind) && $0 != kind }
            let ownText = partOf.filter { inSources.contains($0.key) }.compactMap { texts[$0.key] }.joined(separator: "\n")
            for name in outside where ownText.range(of: "\\b\(NSRegularExpression.escapedPattern(for: name))\\b", options: .regularExpression) != nil {
                neighbours.insert(name)
            }
        }
        partOf = partOf.filter { inSources.contains($0.key) || neighbours.contains($0.value.name) }
        var graph = PlateGraph()
        var filesOf: [String: [URL]] = [:]
        var seen: [String: URL] = [:]
        for (file, part) in partOf {
            filesOf[part.name, default: []].append(file)
            seen[part.name] = part.path
        }
        let names = seen.keys.sorted()
        for name in names {
            let own = (filesOf[name] ?? []).sorted { $0.path < $1.path }
            var part = Part(name: name, path: relative(seen[name]!, to: root))
            part.beside = neighbours.contains(name)
            let main = own.first { $0.deletingPathExtension().lastPathComponent == name } ?? own.first
            part.what = main.flatMap { texts[$0] }.flatMap { what(of: $0, type: name) }
            // A file named `<Part>.<Operation>` is one of its operations (a Granite reducer, a handler).
            var operations = own.compactMap { file -> String? in
                let stem = file.deletingPathExtension().lastPathComponent
                guard stem.hasPrefix(name + "."), stem.count > name.count + 1 else { return nil }
                return String(stem.dropFirst(name.count + 1))
            }
            if operations.isEmpty, let main, let text = texts[main] { operations = functions(in: text) }
            part.operations = Array(Set(operations)).sorted()
            part.agents = own.flatMap { agents(in: texts[$0] ?? "") }
            graph.parts.append(part)
        }
        // An operation most parts share is plumbing (every Granite service has `Set` and `Reply`), not what one does.
        if graph.parts.count >= 3 {
            var shared: [String: Int] = [:]
            for part in graph.parts { for operation in Set(part.operations) { shared[operation, default: 0] += 1 } }
            let plumbing = Set(shared.filter { Double($0.value) >= Double(graph.parts.count) * 0.75 }.keys)
            for i in graph.parts.indices { graph.parts[i].operations.removeAll { plumbing.contains($0) } }
        }
        // Who refers to whom, by the other parts' names in each part's files.
        for from in names {
            for to in names where to != from {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: to) + "\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                var count = 0
                var example: String?
                for file in filesOf[from] ?? [] {
                    for line in (texts[file] ?? "").components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("import "), !trimmed.hasPrefix("#") else { continue }
                        let hits = regex.numberOfMatches(in: line, range: NSRange(line.startIndex..., in: line))
                        guard hits > 0 else { continue }
                        count += hits
                        if example == nil || (example!.count > 110 && trimmed.count <= 110) { example = String(trimmed.prefix(140)) }
                    }
                }
                if count > 0 { graph.references.append(Reference(from: from, to: to, count: count, example: example ?? "")) }
            }
        }
        graph.rank()
        graph.starters = starters(of: Set(names), texts: texts.filter { partOf[$0.key] == nil }, root: root)
        var imports: [String: Int] = [:]
        for text in partOf.keys.compactMap({ texts[$0] }) {
            for line in text.components(separatedBy: .newlines) where line.hasPrefix("import ") {
                let module = line.dropFirst(7).split(separator: " ").last.map(String.init) ?? ""
                if !module.isEmpty, !common.contains(module) { imports[module, default: 0] += 1 }
            }
        }
        graph.imports = imports.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(12).map { ($0.key, $0.value) }
        return graph
    }

    /// Rank: the longest chain of references below a part, so a part that calls others sits above them.
    mutating func rank() {
        var below: [String: Set<String>] = [:]
        for reference in references { below[reference.from, default: []].insert(reference.to) }
        var memo: [String: Int] = [:]
        func depth(_ name: String, _ path: Set<String>) -> Int {
            if let known = memo[name] { return known }
            let next = (below[name] ?? []).filter { !path.contains($0) }
            let value = next.map { depth($0, path.union([name])) + 1 }.max() ?? 0
            memo[name] = value
            return value
        }
        for i in parts.indices { parts[i].rank = depth(parts[i].name, [parts[i].name]) }
    }

    /// Files outside the parts, in the parts' own languages and never a test, that name two or more parts: what starts
    /// the parts.
    static func starters(of parts: Set<String>, texts: [URL: String], root: URL) -> [Starter] {
        guard !parts.isEmpty else { return [] }
        var found: [String: (path: String, parts: Set<String>)] = [:]
        let words = parts.map { ($0, try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b")) }
        for (file, text) in texts {
            let range = NSRange(text.startIndex..., in: text)
            let named = Set(words.compactMap { name, regex in regex?.firstMatch(in: text, range: range) != nil ? name : nil })
            guard named.count >= 2 else { continue }
            let name = declaredTypes(text).first ?? file.deletingPathExtension().lastPathComponent
            found[name, default: (relative(file, to: root), [])].parts.formUnion(named)
        }
        return found.map { Starter(name: $0.key, path: $0.value.path, parts: $0.value.parts.sorted()) }
            .sorted { $0.parts.count == $1.parts.count ? $0.name < $1.name : $0.parts.count > $1.parts.count }
            .prefix(8).map { $0 }
    }

    /// The last word most of the parts' names end in (`SessionService`, `ModelService` → `Service`), when at least two
    /// and half of them share it.
    static func dominantSuffix(_ names: [String]) -> String? {
        var counts: [String: Int] = [:]
        for name in names {
            guard let start = name.lastIndex(where: \.isUppercase), start != name.startIndex else { continue }
            counts[String(name[start...]), default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }),
              best.value >= 2, Double(best.value) >= Double(names.count) / 2 else { return nil }
        return best.key
    }

    // MARK: What the code says

    static func codeFiles(under url: URL) -> [URL] {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) else { return [] }
        guard isFolder.boolValue else { return PlateSources.codeExtensions.contains(url.pathExtension.lowercased()) ? [url.standardizedFileURL] : [] }
        var files: [URL] = []
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey],
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        for case let item as URL in walker {
            if skipped.contains(item.lastPathComponent) { walker.skipDescendants(); continue }
            let ext = item.pathExtension.lowercased()
            if ext != "md", PlateSources.codeExtensions.contains(ext) { files.append(item.standardizedFileURL) }
        }
        return files
    }

    private static let typeLine = try! NSRegularExpression(
        pattern: #"^(?:@\w+(?:\([^)]*\))?\s+)*(?:export\s+)?(?:(?:public|internal|private|fileprivate|open|final|abstract|default|package|nonisolated|indirect|data|sealed)\s+)*(?:struct|class|enum|actor|protocol|interface|type)\s+([A-Z]\w*)"#,
        options: [.anchorsMatchLines])

    static func declaredTypes(_ text: String) -> [String] {
        typeLine.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// The type's own doc comment, or the file's WHAT, as one sentence.
    static func what(of text: String, type: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        if let what = lines.first(where: { $0.hasPrefix("//  WHAT:") || $0.hasPrefix("// WHAT:") }) {
            return sentence(String(what.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces))
        }
        guard let at = lines.firstIndex(where: { declaredTypes($0).first == type }) else { return nil }
        var doc: [String] = []
        var i = at - 1
        while i >= 0, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("///") || lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("@") {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("///") { doc.insert(String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces), at: 0) }
            i -= 1
        }
        return doc.isEmpty ? nil : sentence(doc.joined(separator: " "))
    }

    private static func sentence(_ text: String) -> String {
        let end = text.firstIndex { $0 == "." || $0 == ";" } ?? text.endIndex
        return String(text[..<end].prefix(160)).trimmingCharacters(in: .whitespaces)
    }

    private static let functionLine = try! NSRegularExpression(
        pattern: #"^\s{4}(?:@\w+\s+)*(?:(?:public|internal|open|static|nonisolated|mutating|package)\s+)*func\s+(\w+)"#, options: [.anchorsMatchLines])

    static func functions(in text: String) -> [String] {
        let names = functionLine.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
        return Array(names.filter { !$0.hasPrefix("_") && $0 != "init" }.prefix(8))
    }

    private static let agentLine = try! NSRegularExpression(
        pattern: #"@Agent(?:\((?:[^()]|\([^)]*\))*\))?\s+(?:(?:public|package|internal|private|fileprivate)\s+)?var\s+(\w+)\s*:\s*([\w.]+)"#)

    /// `@Agent var coder: Coder.Agent` declares the agent `coder`.
    static func agents(in text: String) -> [String] {
        agentLine.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let name = Range(match.range(at: 1), in: text), let type = Range(match.range(at: 2), in: text) else { return nil }
            return "\(text[name]) (\(String(text[type]).replacingOccurrences(of: ".Agent", with: "")))"
        }
    }

    private static func relative(_ url: URL, to root: URL) -> String {
        let path = url.standardizedFileURL.path, base = root.standardizedFileURL.path
        return path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : path
    }

    // MARK: Said

    /// The graph as the model reads it.
    func render() -> String {
        guard !parts.isEmpty else { return "" }
        var out = ["## The parts, read off the code (rank: how many parts deep its references go; higher calls lower)"]
        for part in parts.sorted(by: { $0.rank == $1.rank ? $0.name < $1.name : $0.rank > $1.rank }) {
            var line = "- \(part.name) · \(part.path) · rank \(part.rank)" + (part.beside ? " · beside the sources" : "")
            if !part.operations.isEmpty { line += " · operations: " + part.operations.joined(separator: " · ") }
            if !part.agents.isEmpty { line += " · agents: " + part.agents.joined(separator: ", ") }
            if let what = part.what, !what.isEmpty { line += "\n  " + what }
            out.append(line)
        }
        if !references.isEmpty {
            out.append("\n## Who refers to whom (draw arrows only from these; ×n is how often, then a line that shows how)")
            for reference in references.sorted(by: { $0.count == $1.count ? ($0.from, $0.to) < ($1.from, $1.to) : $0.count > $1.count }).prefix(40) {
                out.append("- \(reference.from) → \(reference.to) ×\(reference.count): `\(reference.example)`")
            }
        }
        if !starters.isEmpty {
            out.append("\n## What starts them, from outside these folders (the front ends and the root: the top lanes)")
            for starter in starters { out.append("- \(starter.name) (\(starter.path)) → " + starter.parts.joined(separator: ", ")) }
        }
        if !imports.isEmpty {
            out.append("\n## What they import (a module that is not one of the parts may be across a wire: an external)")
            out.append(imports.map { "\($0.name) ×\($0.count)" }.joined(separator: ", "))
        }
        return out.joined(separator: "\n")
    }
}
