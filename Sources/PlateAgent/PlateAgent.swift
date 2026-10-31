//  WHAT: An editorial architecture plate of a project, as a Granite agent package: the host's model drafts what it
//        says from the project's folders, the kit lays it out in the Rao plate style, WebKit measures it, and the
//        model fixes what overflowed, overlapped or crossed, until it measures clean. Written as a PNG at 2x, with
//        the spec beside it so it can be drawn again without a model.
//  PIN:  THE MODEL SAYS, THE KIT PLACES. The spec is meaning only (lanes, boxes, arrows, the walk); the grid, the
//        routes, the type and the strokes are the package's. A local coder model writes a good spec; it cannot
//        place forty labels without collisions, and it is never asked to.
//  PIN:  NOTHING UNTIL A CALL. The WebKit page and the face are made on the first call (`PlateCompute`).

import Foundation
import GraniteAgents

public struct PlateAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// What to draw, when the ask is not enough: the lanes, and the one path the numbers walk.
        public var brief: String?
        /// The files or folders the plate is drawn from, under `directory`.
        public var sources: [String]?
        /// A finished spec, as the path of its JSON: drawn again with no draft, and no model needed.
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
        "brief": "what to draw: the lanes (tiers, top to bottom) and the one path the numbers walk, end to end",
        "sources": "the folders or files the plate is drawn from, relative to the project",
        "spec": "a .plate.json written by an earlier call, to draw again with edits and no draft",
        "output": "where to write the PNG; docs/README_Assets/<title>.png when the project has that folder",
        "rounds": "how many times to fix what the plate measured; 3 when left out",
    ]
    public static let guide = """
        Ask plate for one picture of one idea: a flow through a system, its services and who calls whom, how a request \
        or a turn passes through it. Give it `sources`: the folders the boxes live in (a Services folder, the Sources \
        tree), not single files. Say in `brief` what you have learned that the files do not say at a glance: the tiers \
        from top to bottom, which parts are agents or across a wire, and the one path the numbers should walk, end to \
        end, in order. It drafts the plate on the loaded model, lays it out, measures it in WebKit and fixes what \
        overflowed, overlapped or crossed, up to `rounds`; a call takes a few minutes. It answers with the PNG (2x) and \
        a .plate.json beside it: to change a word, edit that file and call again with `spec`. Not for charts of \
        numbers, screenshots or pictures that are not a system's structure.
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
