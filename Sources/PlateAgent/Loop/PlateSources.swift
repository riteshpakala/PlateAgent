import Foundation

/// What the model drafts from: the files and folders named in `sources`, read as a digest the model can hold — first
/// the code's own graph (`PlateGraph`: the parts, who refers to whom, what starts them), then a folder's tree, and of
/// each file what says what it is (its opening comment, its type lines, its Granite declarations, its functions),
/// capped, so a folder of forty files fits in a prompt.
struct PlateSources: Sendable {
    let digest: String
    let files: Int

    static let codeExtensions: Set<String> = ["swift", "ts", "tsx", "js", "jsx", "mjs", "py", "go", "rs", "kt", "java", "rb", "m", "mm", "h",
                                              "c", "cc", "cpp", "cs", "php", "scala", "ex", "exs", "md"]
    private static let skipped: Set<String> = [".build", "node_modules", "DerivedData", "Pods", "dist", "build", ".next", "vendor", "__pycache__", ".git"]

    static func read(_ paths: [String], in folder: URL, limit: Int = 32_000, maxFiles: Int = 40) -> PlateSources {
        let manager = FileManager.default
        let named = paths.isEmpty ? [folder.path] : paths
        var files: [URL] = []
        var trees: [String] = []
        for path in named {
            let url = resolve(path, in: folder)
            var isFolder: ObjCBool = false
            guard manager.fileExists(atPath: url.path, isDirectory: &isFolder) else { continue }
            if isFolder.boolValue {
                let (tree, found) = walk(url, root: folder, depth: paths.isEmpty ? 2 : 4)
                trees.append("## \(relative(url, to: folder))/\n" + tree.prefix(120).joined(separator: "\n"))
                files += found
            } else {
                files.append(url)
            }
        }
        let urls = named.map { resolve($0, in: folder) }.filter { manager.fileExists(atPath: $0.path) }
        let graph = PlateGraph.read(urls, root: folder).render()
        let ranked = Array(Self.rank(files, root: folder).prefix(graph.isEmpty ? maxFiles : maxFiles / 2))
        var digest = ([graph] + trees).filter { !$0.isEmpty }.joined(separator: "\n\n")
        var read = 0
        for file in ranked {
            guard digest.count < limit, let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let said = summary(of: text, ext: file.pathExtension.lowercased())
            guard !said.isEmpty else { continue }
            let block = "\n\n## \(relative(file, to: folder))\n" + said
            digest += block.count + digest.count > limit ? String(block.prefix(max(0, limit - digest.count))) : block
            read += 1
        }
        return PlateSources(digest: digest, files: read)
    }

    static func resolve(_ path: String, in folder: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : folder.appendingPathComponent(expanded)
    }

    private static func relative(_ url: URL, to folder: URL) -> String {
        let path = url.standardizedFileURL.path, base = folder.standardizedFileURL.path
        return path.hasPrefix(base + "/") ? String(path.dropFirst(base.count + 1)) : path
    }

    /// A folder's tree to `depth`, and the code files in it.
    private static func walk(_ url: URL, root: URL, depth: Int) -> (tree: [String], files: [URL]) {
        var tree: [String] = [], files: [URL] = []
        func visit(_ dir: URL, _ level: Int) {
            guard level <= depth, let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
            for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = item.lastPathComponent
                guard !name.hasPrefix("."), !skipped.contains(name) else { continue }
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let indent = String(repeating: "  ", count: level)
                if isDir {
                    tree.append(indent + name + "/")
                    visit(item, level + 1)
                } else if codeExtensions.contains(item.pathExtension.lowercased()) {
                    tree.append(indent + name)
                    files.append(item)
                }
            }
        }
        visit(url, 0)
        return (tree, files)
    }

    /// The files most likely to say what a system is: its services, centers, roots, agents, routers, stores and
    /// README first, the shallow before the deep.
    static func rank(_ files: [URL], root: URL) -> [URL] {
        let keys = ["Service", "Center", "Root", "Agent", "Router", "Store", "Controller", "Manager", "App", "README", "main", "index"]
        func score(_ url: URL) -> Int {
            let name = url.deletingPathExtension().lastPathComponent
            var score = keys.contains { name.hasSuffix($0) || name == $0 } ? 0 : 10
            if name.contains("+") || name.contains(".") { score += 4 }
            score += url.pathComponents.count - root.pathComponents.count
            return score
        }
        return files.sorted { (score($0), $0.path) < (score($1), $1.path) }
    }

    /// What a file says it is, in at most 1,600 characters.
    static func summary(of text: String, ext: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var kept: [String] = []
        if ext == "swift" {
            let typeLine = try! NSRegularExpression(pattern: #"^\s{0,4}(@\w+(\([^)]*\))?\s+)*((public|internal|private|fileprivate|open|final|nonisolated|indirect|package)\s+)*(struct|class|enum|actor|protocol|extension)\s+\w"#)
            let funcLine = try! NSRegularExpression(pattern: #"^\s{0,4}(@\w+\s+)*((public|static|internal|private|open|final|nonisolated|mutating|package)\s+)*func\s+\w"#)
            var functions = 0
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let range = NSRange(line.startIndex..., in: line)
                if i < 24, trimmed.hasPrefix("//") { kept.append(trimmed); continue }
                if trimmed.hasPrefix("@Event") || trimmed.hasPrefix("@Agent") || trimmed.hasPrefix("@Relay") || trimmed.hasPrefix("@Store")
                    || trimmed.hasPrefix("@Service") || trimmed.hasPrefix("@Payload") {
                    kept.append(trimmed); continue
                }
                if typeLine.firstMatch(in: line, range: range) != nil {
                    if i > 0, lines[i - 1].trimmingCharacters(in: .whitespaces).hasPrefix("///") { kept.append(lines[i - 1].trimmingCharacters(in: .whitespaces)) }
                    kept.append(trimmed); continue
                }
                if functions < 12, funcLine.firstMatch(in: line, range: range) != nil { kept.append(trimmed); functions += 1 }
            }
        } else {
            kept = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(30).map { $0 }
        }
        let joined = kept.joined(separator: "\n")
        return joined.count > 1_600 ? String(joined.prefix(1_600)) + "\n…" : joined
    }
}
