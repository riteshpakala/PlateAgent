//  WHAT: An editorial plate in the Rao plate style, as a Granite agent package, in one of two forms. An architecture
//        flow of a project: the package reads the code's graph off its folders (its parts, who calls whom, its front
//        ends and root), the host's model plans what the plate says (the lanes, a duty a box, the walk), the package
//        composes it and the kit lays it out. Or an infographic of anything: quotes, a creative piece, an
//        explanation, a process, a few figures, written by the model as blocks the kit sets on a grid. WebKit
//        measures either, and the model revises until it measures clean. Written as a PNG at 2x, with the spec inside
//        it so it can be drawn again, or changed, without a model.
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
        /// "architecture" for a project's flow from its code, "infographic" for anything else; when left out, sources
        /// that hold code are drawn as their architecture and everything else as an infographic.
        public var form: String?
        /// The host's folder.
        public var directory: String?

        public init(brief: String? = nil, sources: [String]? = nil, spec: String? = nil, output: String? = nil, rounds: Int? = nil,
                    form: String? = nil, directory: String? = nil) {
            self.brief = brief; self.sources = sources; self.spec = spec; self.output = output; self.rounds = rounds; self.form = form
            self.directory = directory
        }
    }

    public typealias Event = PlateFrame
    public typealias Output = PlateResult
    public typealias Compute = PlateCompute

    public static let word = "plate"
    public static let summary = "draws an editorial plate as a PNG: an infographic of anything (quotes, a creative piece, an explanation, a process, a few figures) or a project's architecture from its folders."
    public static let fields = [
        "brief": "what the person asked for: for an infographic its subject and what to say; for an architecture the path the numbers walk; never a guess at the architecture",
        "form": "infographic (quotes, a creative piece, an explanation, a process, figures) or architecture (a project's flow from its code); left out, code sources are drawn as their architecture and everything else as an infographic",
        "sources": "the folders or files the plate is drawn from, relative to the project",
        "spec": "a plate's PNG from an earlier call (it carries its spec), to draw again; with a brief, changed as the brief asks",
        "output": "where to write the PNG; docs/README_Assets/<title>.png when the project has that folder",
        "rounds": "how many times to fix what the plate measured; 3 when left out",
    ]
    public static let guide = """
        Ask plate for one picture of one idea, in one of two forms. An infographic of anything: quotes, a poem or a \
        creative piece, how something works, a process, a comparison, a handful of figures; set `form` to \
        "infographic" and say in `brief` what it is about and what it should say (the quotes, their theme, the facts), \
        with no `sources`, or with `sources` when it explains files. A quote credits a speaker only when the person's own \
        ask names them, or a source file does: never add a name to `brief` the person did not give; asked for quotes \
        with no names, it writes its own lines. The model writes it as blocks (quotes, cards, \
        steps, lists, figures, a flow of stops, a simple drawing) and the kit sets them on a grid in the plate style. \
        Or an architecture: a flow through a system, its services and who calls whom, how a request or a turn passes \
        through it; set `form` to "architecture" and give `sources`, the folders the parts live in. It reads the code \
        itself, so `brief` says only which path the numbers should walk and what to put first; never guess the \
        architecture in `brief`. Either way it measures the plate in WebKit and revises what overflowed, up to \
        `rounds`; a call takes a few minutes. It answers with the PNG (2x), which carries the spec it was drawn from: \
        to change a plate, call again with `spec` set to its PNG and say the change in `brief`. Not for charts of a \
        series of numbers or screenshots.
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
