//  WHAT: An editorial architecture plate of a project, as a Granite agent package: the package reads the code's
//        graph off the project's folders (its parts, who calls whom, its front ends and root), the host's model
//        plans what the plate says (the lanes, a duty a box, the walk), the package composes it, the kit lays it
//        out in the Rao plate style, WebKit measures it, and the model revises the plan until it measures clean.
//        Written as a PNG at 2x, with the spec inside it so it can be drawn again, or changed, without a model.
//  PIN:  THE MODEL SAYS, THE KIT PLACES. The spec is meaning only (lanes, boxes, arrows, the walk); the grid, the
//        routes, the type and the strokes are the package's. A local coder model writes a good spec; it cannot
//        place forty labels without collisions, and it is never asked to.
//  PIN:  NOTHING UNTIL A CALL. The WebKit page and the face are made on the first call (`PlateCompute`).

import Foundation
import GraniteAgents

public struct PlateAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// What the person asked for, when the ask does not say it: the path the numbers walk, what to put first.
        public var brief: String?
        /// The files or folders the plate is drawn from, under `directory`.
        public var sources: [String]?
        /// A plate drawn before, as its PNG (which carries its spec) or a spec's JSON: drawn again with no draft, and
        /// no model needed unless `brief` asks for a change.
        public var spec: String?
        /// Where to write the PNG; the project's pictures folder, named for the title, when left out.
        public var output: String?
        /// How many times the model may fix what the plate measured; 3 when left out.
        public var rounds: Int?
        /// The host's folder.
        public var directory: String?

        public init(brief: String? = nil, sources: [String]? = nil, spec: String? = nil, output: String? = nil, rounds: Int? = nil,
                    directory: String? = nil) {
            self.brief = brief; self.sources = sources; self.spec = spec; self.output = output; self.rounds = rounds; self.directory = directory
        }
    }

    public typealias Event = PlateFrame
    public typealias Output = PlateResult
    public typealias Compute = PlateCompute

    public static let word = "plate"
    public static let summary = "draws an editorial architecture plate of a project — its flow, its services, who calls whom — from its folders, and writes it as a PNG."
    public static let fields = [
        "brief": "what the person asked for: the path the numbers walk, what to put first; never a guess at the architecture",
        "sources": "the folders or files the plate is drawn from, relative to the project",
        "spec": "a plate's PNG from an earlier call (it carries its spec), to draw again; with a brief, changed as the brief asks",
        "output": "where to write the PNG; docs/README_Assets/<title>.png when the project has that folder",
        "rounds": "how many times to fix what the plate measured; 3 when left out",
    ]
    public static let guide = """
        Ask plate for one picture of one idea: a flow through a system, its services and who calls whom, how a request \
        or a turn passes through it. Give it `sources`: the folders the parts live in (a Services folder, a Sources \
        tree). It reads the code itself — the parts, who refers to whom, the agents they run, what starts them, \
        including the same kind of part in other folders — so `brief` says only what the person asked for: which path \
        the numbers should walk, what to put first. Never guess the architecture in `brief`; a guess that the code \
        does not bear out is drawn over. Call it once you know which folders; there is no need to read them first. It \
        plans the plate on the loaded model, composes it from the code, lays it out, measures it in WebKit and revises \
        what overflowed, overlapped or crossed, up to `rounds`; a call takes a few minutes. It answers with the PNG (2x), which carries the spec it \
        was drawn from: to change a plate, call again with `spec` set to its PNG and say the change in `brief`. Not for \
        charts of numbers, screenshots or pictures that are not a system's structure.
        """
    /// One WebKit page draws every plate: calls take turns.
    public static let lanes: Int? = 1

    public static func compute() async throws -> PlateCompute { await MainActor.run { PlateCompute() } }
    public static func output(from events: [PlateFrame]) -> PlateResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<PlateFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await PlateLoop(input: input, context: context, yield: { continuation.yield($0) }).run()
                    continuation.yield(.written(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
