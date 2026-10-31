import Foundation
@testable import PlateAgent

/// Craft's flow plate (docs/README_Assets/flow.png) said as a spec: what the package is held to drawing well.
enum Fixture {
    static let flow = PlateSpec(
        caption: "RAO STUDIOS · CRAFT · THE FLOW",
        title: "One turn, every service",
        subtitle: "from the ask to the records: what each service is responsible for, in the order a turn passes through it",
        heading: "A turn, through the services",
        machine: "ONE ASK, END TO END",
        tag: "every box is a service or an agent in Sources/CraftAgents, Sources/CraftRuntime and Sources/CraftApp",
        lanes: [
            PlateLane(id: "front", name: "the front ends", colour: .dial),
            PlateLane(id: "root", name: "the root", colour: .dial),
            PlateLane(id: "turn", name: "a turn", colour: .blue),
            PlateLane(id: "project", name: "the project", colour: .green, columns: 2),
            PlateLane(id: "machine", name: "the machine", colour: .orange, columns: 2, beside: true),
        ],
        nodes: [
            PlateNode(id: "craft", lane: "front", name: "craft", duty: "the REPL, -p, and models · index · records · stacks", code: "CraftCLI"),
            PlateNode(id: "app", lane: "front", name: "Craft.app", duty: "a window per component; a page reads services under a RelayClock", code: "CraftApp/Components"),
            PlateNode(id: "approot", lane: "front", name: "CraftAppRoot", duty: "the façade AppKit calls: windows, folders, parking, tabs", code: "CraftApp/CraftAppRoot"),
            PlateNode(id: "environment", lane: "front", name: "EnvironmentService", duty: "frontmost or parked, a signalled quit, the gate, tabs, this Mac",
                      code: "CraftApp/Services/EnvironmentService"),
            PlateNode(id: "root", lane: "root", name: "CraftRuntimeRoot", duty: "boots the services, holds a relay to each, installs three handlers",
                      code: "CraftRuntime/Root"),
            PlateNode(id: "session", lane: "turn", name: "SessionService",
                      duty: "opens a session, performs its turn, then reads the facts, checks the references, counts the recall",
                      code: "Open · Send · Spawn · Control · Close · Halt"),
            PlateNode(id: "transcript", lane: "turn", name: "TranscriptService", duty: "the transcript, modes and attention of every open session",
                      code: "Open · Close · Apply"),
            PlateNode(id: "model", lane: "turn", name: "ModelService", duty: "the one model: catalog, install, memory, the ceiling, pressure",
                      code: "Refresh · Install · Memory · Pressure", colour: .orange),
            PlateNode(id: "mlx", lane: "turn", name: "MLX", code: "through Frigate", kind: .external),
            PlateNode(id: "coder", lane: "turn", name: "coder", code: "steered while live", kind: .agent, under: "transcript"),
            PlateNode(id: "worker", lane: "turn", name: "worker", code: "session/child · ×4", kind: .agent, under: "transcript"),
            PlateNode(id: "records", lane: "project", name: "RecordsService", duty: "what Craft learned per project: keepers, recall, read, delete, archive"),
            PlateNode(id: "project", lane: "project", name: "ProjectService", duty: "the projects a person opened, persisted; their facts"),
            PlateNode(id: "watch", lane: "project", name: "WatchService", duty: "every reason a project’s files may have changed knocks on one door"),
            PlateNode(id: "thread", lane: "project", name: "ThreadService", duty: "Craft’s lane of the AII index: start, stop, refresh, rebuild"),
            PlateNode(id: "aii", lane: "project", name: "Thread, in AII", code: "the index every Rao app shares", kind: .external, under: "thread"),
            PlateNode(id: "stacks", lane: "machine", name: "StacksService", duty: "what a project is built with, as packages: refresh, probe, build"),
            PlateNode(id: "config", lane: "machine", name: "ConfigService", duty: "config.json, global and per project: load and write"),
            PlateNode(id: "update", lane: "machine", name: "UpdateService", duty: "the feed, the verified pkg, Installer, the six-hour loop"),
            PlateNode(id: "account", lane: "machine", name: "AccountService", duty: "the Rao account through the local Sewn: follow, sign in, out"),
            PlateNode(id: "sewn", lane: "machine", name: "Sewn, in AII", code: "sign-in and the account’s tokens", kind: .external, under: "account"),
        ],
        edges: [
            PlateEdge(from: "craft", to: "root", colour: .gold),
            PlateEdge(from: "approot", to: "root", label: "boot · open · turn", number: 1, colour: .gold),
            PlateEdge(from: "app", to: "approot"),
            PlateEdge(from: "approot", to: "environment"),
            PlateEdge(from: "root", to: "session", style: .dashedGrey),
            PlateEdge(from: "session", to: "transcript", label: "open · ask", number: 2),
            PlateEdge(from: "transcript", to: "worker", label: "perform", number: 3, style: .dashedGold),
            PlateEdge(from: "worker", to: "mlx", label: "a run → generate", number: 4, style: .dashedGold),
            PlateEdge(from: "coder", to: "transcript", label: "frames", number: 5, style: .dashedGold),
            PlateEdge(from: "session", to: "records", label: "recall · flush", number: 6),
            PlateEdge(from: "session", to: "project", label: "facts", number: 7),
            PlateEdge(from: "session", to: "watch", label: "warm · index", number: 8),
            PlateEdge(from: "watch", to: "thread", label: "files · searches", number: 9, style: .dashedGrey, colour: .green),
            PlateEdge(from: "thread", to: "aii", number: 10, style: .dashedGrey, both: true),
            PlateEdge(from: "model", to: "root", label: "held → halt", number: 11, style: .dashedGrey),
            PlateEdge(from: "transcript", to: "app", label: "read under a RelayClock", number: 12, style: .dashedGold),
            PlateEdge(from: "session", to: "model", label: "route(.model) · halt"),
            PlateEdge(from: "records", to: "watch", label: "attach"),
            PlateEdge(from: "model", to: "config", label: "load · write"),
            PlateEdge(from: "account", to: "sewn", style: .dashedGrey, both: true),
        ],
        legend: "Each box is a **GraniteService**; its line says what it is responsible for, and nothing else is. Solid arrows are dispatches down "
            + "the relay graph; {gold:dashed gold} is an agent’s run and what it writes; dashed grey is the root observing a service and calling "
            + "down, or a process across a wire. The numbers walk one turn.")

    /// A folder of its own for one test, removed with the process's temporary files.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plate-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The spec written as a `.plate.json` in `folder`.
    static func write(_ spec: PlateSpec, to folder: URL, name: String = "flow.plate.json") throws -> URL {
        let url = folder.appendingPathComponent(name)
        try JSONEncoder().encode(spec).write(to: url)
        return url
    }
}
