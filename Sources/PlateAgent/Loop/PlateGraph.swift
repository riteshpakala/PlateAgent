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
        /// What `from` calls on `to`, most used first: `transcripts.center.open.send(…)` is `open`.
        var calls: [String] = []
    }

    struct Starter: Sendable, Equatable {
        let name: String
        let path: String
        let parts: [String]
        var what: String? = nil
        /// The other starters it names: a front end reaching the root, an app's root reaching a service it holds.
        var reaches: [String] = []
        /// What a person runs (a command line, an app: a product of the project), or a service a front end holds.
        var role: Role = .file

        enum Role: String, Sendable { case file, entry, held }
    }

    var parts: [Part] = []
    var references: [Reference] = []
    var starters: [Starter] = []
    /// The starter that holds the parts: it names three in four of them, and the most.
    var root: String?
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
        let outside = partOf.filter { !inSources.contains($0.key) && !neighbours.contains($0.value.name) }
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
            // In the order the part declares its events (its author's order), else by name.
            let events = own.flatMap { events(in: texts[$0] ?? "") }
            part.operations = Array(Set(operations)).sorted { (events.firstIndex(of: $0.lowercased()) ?? Int.max, $0) < (events.firstIndex(of: $1.lowercased()) ?? Int.max, $1) }
            part.agents = own.flatMap { agents(in: texts[$0] ?? "") }
            graph.parts.append(part)
        }
        // An operation most parts share is plumbing (every Granite service has `Set` and `Reply`), not what one does.
        var plumbing: Set<String> = ["Set", "Reply"]
        if graph.parts.count >= 3 {
            var shared: [String: Int] = [:]
            for part in graph.parts { for operation in Set(part.operations) { shared[operation, default: 0] += 1 } }
            plumbing.formUnion(shared.filter { Double($0.value) >= Double(graph.parts.count) * 0.75 }.keys)
        }
        for i in graph.parts.indices { graph.parts[i].operations.removeAll { plumbing.contains($0) } }
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
                if count > 0 {
                    let fromText = (filesOf[from] ?? []).compactMap { texts[$0] }.joined(separator: "\n")
                    graph.references.append(Reference(from: from, to: to, count: count, example: example ?? "", calls: calls(from: fromText, to: to)))
                }
            }
        }
        graph.rank()
        graph.starters = starters(of: Set(names), texts: texts.filter { partOf[$0.key] == nil }, root: root)
        // The root holds three in four of the parts; of two that do (an app's root and the runtime's), the one the other names.
        let holders = graph.starters.filter { Double($0.parts.count) >= Double(names.count) * 0.75 && $0.parts.count >= 2 }
        func namedBy(_ starter: Starter) -> Int {
            holders.filter { other in
                other.name != starter.name && text(of: other, in: texts, root: root).range(of: "\\b" + NSRegularExpression.escapedPattern(for: starter.name) + "\\b", options: .regularExpression) != nil
            }.count
        }
        graph.root = holders.max { (namedBy($0), $0.parts.count) < (namedBy($1), $1.parts.count) }?.name
        graph.front(texts: texts, outside: outside, kind: kind, root: root)
        // What only the root calls is its wiring at boot (`connect`): last, after what the part is for.
        if let holder = graph.root, let starter = graph.starters.first(where: { $0.name == holder }) {
            let said = text(of: starter, in: texts, root: root)
            for i in graph.parts.indices {
                let wiring = Set(callCounts(from: said, to: graph.parts[i].name).keys.map { $0.lowercased() })
                let ops = graph.parts[i].operations
                graph.parts[i].operations = ops.filter { !wiring.contains($0.lowercased()) } + ops.filter { wiring.contains($0.lowercased()) }
            }
        }
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
        var found: [String: (path: String, parts: Set<String>, what: String?)] = [:]
        let words = parts.map { ($0, try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b")) }
        for (file, text) in texts {
            let range = NSRange(text.startIndex..., in: text)
            let named = Set(words.compactMap { name, regex in regex?.firstMatch(in: text, range: range) != nil ? name : nil })
            guard named.count >= 2 else { continue }
            let name = declaredTypes(text).first ?? file.deletingPathExtension().lastPathComponent
            found[name, default: (relative(file, to: root), [], what(of: text, type: name))].parts.formUnion(named)
        }
        return found.map { Starter(name: $0.key, path: $0.value.path, parts: $0.value.parts.sorted(), what: $0.value.what) }
            .sorted { $0.parts.count == $1.parts.count ? $0.name < $1.name : $0.parts.count > $1.parts.count }
            .prefix(8).map { $0 }
    }

    /// The front ends, read off the code: what a person runs (the project's executables, from its manifest), the
    /// starters that name the root, and a service of the parts' kind that one of those holds rather than a part (an
    /// app's environment). Each says which other starters it reaches.
    mutating func front(texts: [URL: String], outside: [URL: (name: String, path: URL)], kind: String?, root: URL) {
        func text(of starter: Starter) -> String { Self.text(of: starter, in: texts, root: root) }
        func names(_ candidates: [String], in text: String) -> [String] {
            candidates.filter { text.range(of: "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b", options: .regularExpression) != nil }
        }
        let partNames = parts.map(\.name)
        // A service a front end holds: of the parts' kind, outside the sources, named by a starter that names the root.
        if let kind, let holder = self.root {
            var held: [String: URL] = [:]
            for (_, part) in outside where part.name.hasSuffix(kind) && part.name != kind && !partNames.contains(part.name) { held[part.name] = part.path }
            for i in starters.indices where starters[i].name != holder {
                let said = text(of: starters[i])
                guard !names([holder], in: said).isEmpty else { continue }
                for name in names(held.keys.sorted(), in: said) where !starters.contains(where: { $0.name == name }) {
                    let folder = held[name]!
                    let own = texts.filter { $0.key.path.hasPrefix(folder.path + "/") || $0.key == folder }
                    let main = own.first { $0.key.deletingPathExtension().lastPathComponent == name }?.value ?? ""
                    starters.append(Starter(name: name, path: Self.relative(folder, to: root), parts: names(partNames, in: own.values.joined(separator: "\n")),
                                            what: Self.what(of: main, type: name), role: .held))
                }
            }
        }
        // What a person runs: each executable the manifest declares, named as it is run.
        starters.insert(contentsOf: Self.entries(in: root, texts: texts, holder: self.root, starters: starters), at: 0)
        // Who reaches whom among them: a front end the root, and a service it holds. A page that names the parts but not
        // the root is not a front end.
        let all = starters.map(\.name)
        for i in starters.indices where starters[i].role == .file && starters[i].name != self.root {
            let said = text(of: starters[i])
            guard let holder = self.root, !names([holder], in: said).isEmpty else { continue }
            starters[i].reaches = names(all.filter { $0 != starters[i].name }, in: said).filter { name in
                name == holder || starters.first { $0.name == name }?.role == .held
            }
        }
    }

    /// A starter's file and its extensions beside it (`CraftRuntimeRoot+Boot.swift`): what the type says, wherever it says it.
    static func text(of starter: Starter, in texts: [URL: String], root: URL) -> String {
        let file = root.appendingPathComponent(starter.path).standardizedFileURL
        let folder = file.deletingLastPathComponent().path, stem = file.deletingPathExtension().lastPathComponent
        return texts.filter { url, _ in
            url == file || (url.deletingLastPathComponent().path == folder && url.deletingPathExtension().lastPathComponent.hasPrefix(stem + "+"))
        }.sorted { $0.key.path < $1.key.path }.map(\.value).joined(separator: "\n")
    }

    /// The executables `Package.swift` declares: a command line by its product's name, an app (its code runs an
    /// `NSApplication` or a SwiftUI `App`) as `<Package>.app`; each with what its code says it is and the starter it
    /// reaches: the one in its module that names the root, else the root.
    static func entries(in folder: URL, texts: [URL: String], holder root: String?, starters: [Starter]) -> [Starter] {
        guard let manifest = try? String(contentsOf: folder.appendingPathComponent("Package.swift"), encoding: .utf8) else { return [] }
        let package = manifest.firstMatch(of: #/Package\(\s*name:\s*"([^"]+)"/#).map { String($0.1) }
        var found: [Starter] = []
        for match in manifest.matches(of: #/\.executable\(\s*name:\s*"([^"]+)"\s*,\s*targets:\s*\[\s*"([^"]+)"/#) {
            let product = String(match.1), target = String(match.2)
            let module = folder.appendingPathComponent("Sources").appendingPathComponent(target).standardizedFileURL
            let own = texts.filter { $0.key.path.hasPrefix(module.path + "/") }
            guard !own.isEmpty else { continue }
            let joined = own.values.joined(separator: "\n")
            let isApp = joined.contains("NSApplication") || joined.contains("UIApplicationMain") || joined.contains("WindowGroup")
            let name = isApp ? (package ?? product) + ".app" : product
            // What it is: its entry's abstract (a command line's), else the entry file's opening comment.
            let entryText = own.first { $0.value.contains("@main") }?.value ?? own.first { $0.key.lastPathComponent == "main.swift" }?.value ?? ""
            var what = entryText.firstMatch(of: #/abstract:\s*"([^"]+)"/#).map { String($0.1) }
            if let said = what, let dash = said.range(of: " — "), said[..<dash.lowerBound].trimmingCharacters(in: .whitespaces) == product {
                what = String(said[dash.upperBound...])
            }
            if what == nil, !entryText.isEmpty {
                let comment = entryText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
                    .drop { !$0.hasPrefix("//") && !$0.isEmpty && $0.hasPrefix("import") || $0.isEmpty }
                    .prefix { $0.hasPrefix("//") }.map { $0.drop { $0 == "/" }.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                what = comment.isEmpty ? nil : firstSentence(comment)
            }
            var reaches: [String] = []
            if let root {
                let inModule = starters.filter { $0.role == .file && $0.name != root && $0.path.hasPrefix("Sources/\(target)/") }
                    .filter { starter in texts.contains { relative($0.key, to: folder) == starter.path && $0.value.contains(root) } }
                reaches = inModule.isEmpty ? (joined.contains(root) ? [root] : []) : inModule.map(\.name)
            }
            found.append(Starter(name: name, path: "Sources/" + target, parts: [], what: what, reaches: reaches, role: .entry))
        }
        return found
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

    /// Words that say how something is called, not what is called: Granite's plumbing and a value's own.
    private static let plumbing: Set<String> = ["center", "state", "send", "perform", "attach", "events", "wait", "value", "shared", "init",
                                                "self", "Center", "Meta", "Reducer", "State", "Type", "isLive", "description", "set", "Set", "reply", "Reply"]

    /// What `text` calls on `type`: the members it reaches through a variable of that type (`transcripts.center.open`
    /// is `open`) or on the type itself (`WatchService.engine` is `engine`), most used first, three at most.
    static func calls(from text: String, to type: String) -> [String] {
        callCounts(from: text, to: type).sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(3).map(\.key)
    }

    /// Each member `text` reaches on `type`, and how often.
    static func callCounts(from text: String, to type: String) -> [String: Int] {
        let range = NSRange(text.startIndex..., in: text)
        let escaped = NSRegularExpression.escapedPattern(for: type)
        var names: Set<String> = []
        if let declaration = try? NSRegularExpression(pattern: #"\b(\w+)\s*:\s*(?:\w+\.)*"# + escaped + #"\b"#) {
            for match in declaration.matches(in: text, range: range) {
                if let r = Range(match.range(at: 1), in: text) { names.insert(String(text[r])) }
            }
        }
        var counts: [String: Int] = [:]
        let receivers = names.map(NSRegularExpression.escapedPattern(for:)) + [escaped]
        for receiver in receivers {
            guard let use = try? NSRegularExpression(pattern: #"\b"# + receiver + #"\.(?:center\.)?([a-zA-Z_]\w*)"#) else { continue }
            for match in use.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let member = String(text[r])
                if !plumbing.contains(member) { counts[member, default: 0] += 1 }
            }
        }
        return counts
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
        if let start = lines.firstIndex(where: { $0.hasPrefix("//  WHAT:") || $0.hasPrefix("// WHAT:") }) {
            // The header wraps: its continuation lines run until the next key (IN:, OUT:, PIN:) or the end of the comment.
            var text = String(lines[start].split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces)
            for line in lines.dropFirst(start + 1) {
                guard line.hasPrefix("//") else { break }
                let body = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if body.isEmpty || body.firstMatch(of: #/^[A-Z]{2,}:/#) != nil { break }
                text += " " + body
            }
            return sentence(text)
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

    /// The first sentence, whole: a cut is the composer's, at a clause.
    private static func sentence(_ text: String) -> String {
        String(firstSentence(text).prefix(400)).trimmingCharacters(in: .whitespaces)
    }

    /// Up to the first `.` or `;` that ends a sentence (a space or the end after it), never the dot of `Craft.app`.
    static func firstSentence(_ text: String) -> String {
        guard let match = text.firstMatch(of: #/[.;](\s|$)/#) else { return text }
        return String(text[..<match.range.lowerBound])
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

    private static let eventLine = try! NSRegularExpression(pattern: #"@Event(?:\([^)]*\))?\s+(?:(?:public|package|internal|private|fileprivate)\s+)?var\s+(\w+)\s*:"#)

    /// `@Event var open: Open.Reducer` declares the event `open`: in the order the part declares them, lowercased.
    static func events(in text: String) -> [String] {
        eventLine.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]).lowercased() }
        }
    }

    /// `@Agent var coder: Coder.Agent` declares the agent `coder`.
    static func agents(in text: String) -> [String] {
        agentLine.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let name = Range(match.range(at: 1), in: text), let type = Range(match.range(at: 2), in: text) else { return nil }
            return "\(text[name]) (\(String(text[type]).replacingOccurrences(of: ".Agent", with: "")))"
        }
    }

    static func relative(_ url: URL, to root: URL) -> String {
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
            if let what = part.what, !what.isEmpty { line += "\n  " + (what.count > 220 ? String(what.prefix(219)) + "…" : what) }
            out.append(line)
        }
        if !references.isEmpty {
            out.append("\n## Who refers to whom (draw arrows only from these; ×n is how often, then a line that shows how)")
            for reference in references.sorted(by: { $0.count == $1.count ? ($0.from, $0.to) < ($1.from, $1.to) : $0.count > $1.count }).prefix(40) {
                out.append("- \(reference.from) → \(reference.to) ×\(reference.count)"
                           + (reference.calls.isEmpty ? "" : " · calls " + reference.calls.joined(separator: ", ")) + ": `\(reference.example)`")
            }
        }
        let front = starters.filter { $0.role != .file || $0.name == root || !$0.reaches.isEmpty }
        if !front.isEmpty {
            out.append("\n## The front ends and the root (the top lanes: what a person runs and what it holds, then the root that holds the parts)")
            for starter in front {
                var line = "- \(starter.name)"
                switch starter.role {
                case .entry: line += " · what a person runs · \(starter.path)"
                case .held: line += " · a service the front end holds · \(starter.path)"
                case .file: line += starter.name == root ? " · the root: it holds \(starter.parts.count) of the \(parts.count) parts · \(starter.path)" : " · \(starter.path)"
                }
                if !starter.reaches.isEmpty { line += " → " + starter.reaches.joined(separator: ", ") }
                if starter.name != root, starter.role != .entry, !starter.parts.isEmpty { line += " · names " + starter.parts.joined(separator: ", ") }
                if let what = starter.what, !what.isEmpty { line += "\n  " + (what.count > 220 ? String(what.prefix(219)) + "…" : what) }
                out.append(line)
            }
        }
        let others = starters.filter { !front.contains($0) }
        if !others.isEmpty {
            out.append("\n## Other files that name the parts (pages and tools: a box only when the request is about them)")
            for starter in others { out.append("- \(starter.name) (\(starter.path)) → " + starter.parts.joined(separator: ", ")) }
        }
        if !imports.isEmpty {
            out.append("\n## What they import (a module that is not one of the parts may be across a wire: an external)")
            out.append(imports.map { "\($0.name) ×\($0.count)" }.joined(separator: ", "))
        }
        return out.joined(separator: "\n")
    }
}
