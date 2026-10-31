import Foundation

/// What the model is told: how a good plate reads (the rules Craft's own plates follow, said as instructions), a
/// worked example from another system to copy the shape of, and the keys. Then what to draw, or what to fix.
///
/// PIN: the example is another system's. A local model copies the example it is shown; one drawn from the system
/// it is asked about would come back with the example's boxes. The schema rides after the example, as a reference
/// (the host says so), never as the last word the model reads before answering.
enum PlateDraft {
    static let rules = """
    You draw one editorial plate of a software system: lanes of boxes and the arrows between them. You answer with the plate's spec, one JSON object. The kit draws it; you decide what it says.

    How a good plate reads:
    - One picture of one idea. The lanes are the system's tiers, top to bottom in the order the thing flows: what starts it at the top, what everything rests on at the foot. Two to six lanes.
    - A lane holds one tier's parts, two to five boxes; four fit across a lane, two across a lane `beside` the one before it. Two small tiers that sit at the same depth go `beside` each other.
    - A box is one part. `name` is its type or module as the code names it (at most 28 characters). `duty` is ONE sentence of what it is responsible for and nothing else, in plain words (at most 100 characters). `code` is where it lives or what it answers to: its folder, or its operations joined by " · " (at most 48 characters).
    - `kind`: "service" for a part of the system; "agent" for something that runs on a model or streams a run back (its `code` at most 22 characters); "external" for a process across a wire, a store, a framework it calls (its `code` at most 30 characters). Put an agent or a store `under` the box that runs or reaches it, in the same lane.
    - An arrow is a call or a hand-off between two boxes. `style`: "solid" for a call down the graph; "dashedGold" for an agent's run and what it writes back; "dashedGrey" for a box observing another and calling back, or a process across a wire. `label` is one to three words of code joined by " · " ("route", "render · page").
    - The numbers walk ONE path, end to end, 1 to n in the order it happens: the path the person asked about. Arrows off that path have no number. At most 12.
    - A lane may carry a `note`: one line no box says, what holds the lane together ("{dial:on boot:} the stores open » the cache warms · a crash » the queue drains"), at most 140 characters.
    - Lane `colour`: "dial" for the frame (front ends, entry points, the root), then one of "blue", "green", "orange", "violet", "red" for each tier. A box may take another colour to say it belongs to another tier.
    - `caption` is "RAO STUDIOS · <PROJECT> · THE <WHAT>" in capitals. `title` is a short editorial sentence with a turn of phrase, never a label (at most 30 characters): "One request, every layer", "One build, every cache" — not "Service pattern flow". `subtitle` is the plate's thesis in one line (at most 100 characters): "from the click to the stored post: what each layer owns, in the order a request passes through it". `heading` names the walk ("A request, through the layers"). `machine` is two to five words in capitals ("ONE CLICK, END TO END"). `tag` says where every box lives in the code.
    - `legend`: one or two sentences on what a box is, what each stroke used means, and what the numbers walk. `**word**` marks a term; `{gold:dashed gold}` colours the gold stroke's name.
    - Every id is a short slug; every `lane`, `under`, `from` and `to` is an id you declared. Draw only what the sources show: never a box the code does not have, never a name it does not use.

    When the sources come with their graph (the parts, who refers to whom, what starts them), draw from it, and where a brief and the graph disagree about who calls whom, the graph is right:
    - The top lanes are what starts the parts: first the front ends (an app, a command line, its pages), then the root that holds the parts, both "dial". Name a lane for what its boxes are ("the front ends", "the root").
    - Then the parts, a lane for each rank, highest first: a part of rank 2 refers to parts of rank 1, which refer to rank 0. The lowest rank may split into two lanes `beside` each other by what they work on ("the data", "the outside"). A rank of one part may join the lane above or below it.
    - An arrow is one of the references listed, from the part that refers to the part it names. Its `label` is what the shown line does, one to three words of code ("route", "render · page"). Number the arrows of the one path the person asked about, in the order it happens; draw the others the reader needs without a number.
    - A part's agents (`agents:`) each go `under` it, `kind` "agent", and an arrow from the part to its agent is "dashedGold". A module the parts import that is not one of them, or a server, a store or an engine they reach, is an "external", `under` the part that reaches it.
    - A part's `code` is its operations, the five that matter most, joined by " · " ("Place · Cancel · Refund · Ship"), or its folder. Its `duty` says what the part is responsible for, from its line in the graph.
    """

    /// A plate of another system: what the model copies the shape of.
    static let example = """
    {"caption": "RAO STUDIOS · ATELIER · THE REQUEST", "title": "One request, every layer",
     "subtitle": "from the click to the stored post: what each layer owns, in the order a request passes through it",
     "heading": "A request, through the layers", "machine": "ONE CLICK, END TO END", "tag": "every box is a module in app/ and lib/",
     "lanes": [{"id": "edge", "name": "the edge", "colour": "dial"}, {"id": "server", "name": "the server", "colour": "blue"},
               {"id": "data", "name": "the data", "colour": "green"}, {"id": "outside", "name": "the outside", "colour": "orange", "beside": true}],
     "nodes": [{"id": "middleware", "lane": "edge", "name": "middleware", "duty": "signs the session cookie and turns a bot away", "code": "middleware.ts"},
               {"id": "page", "lane": "edge", "name": "PostPage", "duty": "renders a post and its form, and posts the form back", "code": "app/posts/[slug]/page.tsx"},
               {"id": "action", "lane": "server", "name": "savePost", "duty": "checks the form, writes the post, asks for a summary", "code": "app/posts/actions.ts"},
               {"id": "summary", "lane": "server", "name": "summarize", "kind": "agent", "code": "a run on the model", "under": "action"},
               {"id": "cache", "lane": "server", "name": "PostCache", "duty": "keeps rendered posts until one is written", "code": "lib/cache.ts"},
               {"id": "store", "lane": "data", "name": "PostStore", "duty": "every post and its revisions, by slug", "code": "lib/store.ts"},
               {"id": "db", "lane": "outside", "name": "Postgres", "kind": "external", "code": "the posts' rows"}],
     "edges": [{"from": "middleware", "to": "page", "label": "session"},
               {"from": "page", "to": "action", "label": "submit", "number": 1},
               {"from": "action", "to": "store", "label": "write", "number": 2},
               {"from": "store", "to": "db", "label": "insert", "style": "dashedGrey", "both": true, "number": 3},
               {"from": "action", "to": "summary", "label": "run", "style": "dashedGold", "number": 4},
               {"from": "summary", "to": "action", "label": "summary", "style": "dashedGold"},
               {"from": "action", "to": "cache", "label": "invalidate", "number": 5}],
     "legend": "Each box is a **module**; its line says what it owns. Solid arrows are calls; {gold:dashed gold} is a model's run and what it writes back; dashed grey is a process across a wire. The numbers walk one request."}
    """

    /// What the model is told when the code's graph is known: plan, and the kit composes.
    static let planRules = """
    You plan one editorial plate of a software system. The kit draws it from the code's own graph: the front ends and the root in the top two lanes, each box's code line, its agents, the arrows the code has, the header and the legend. You decide what the graph cannot: how the parts group into lanes, a line of duty for each box, the walk the numbers take, what is across a wire, and three words for the header. Answer with the plan, one compact JSON object.

    - `unit` is what one pass of the walk carries, one word as the code says it (what a person sends in and the parts pass along). `start` is where it starts, one or two words (what the person does first); `end` is what it leaves behind, one or two words. The header reads "One <unit>, every <kind of part>" and "from the <start> to the <end>". `subject` is what the plate shows, one word: "flow" when the person asks for a flow.
    - `lanes` hold the parts, below the front ends and the root, which are drawn for you. First a lane for the parts the walk passes through first (blue, named "a <unit>"), then the rest by the scope they work on, narrower first: what one project, document or user owns (green), then what the whole machine or app shares (orange). Each lane is named for what its boxes are, "the <noun>". Two to four lanes; at most four boxes in a lane.
    - `boxes` are the parts' names exactly as the graph writes them. Every part goes in a lane. A part's agents are drawn under it for you: never list them as boxes.
    - `duties`: for EVERY box (the front ends and the root too), one line of what it is responsible for, in your own plain words, lowercase, at most 70 characters, read off its line in the graph: what it holds, then what it does. Never the box's own name, never "a service that".
    - `rootNote`: one line on what the root does that no box says, read off its line in the graph (the handlers it installs and what each answers), as "{dial:<what they are>:} <event> » <answer> · <event> » <answer>".
    - `walk` is the one path the person asked about, in the order it happens, six to twelve steps, each from a box to a box, an agent or an external. It starts where a person starts it: each front end into the root (two ways into one box share a number), then down through the root to the part that does the work, out to its agents and what they reach, then to what the work leaves behind. Each step is one of the graph's references, a front end's arrow, a part running one of its agents, or a part reaching an external. Give each a `label`: one to three words of code joined by " · ", what the shown line calls.
    - `externals`: the engines, servers and stores the parts reach across a wire, read off the imports and the parts' lines, each `under` the part that reaches it, with a few words of `what`.
    - Use only names the graph has. The example below is another system: never its names, its words or its duties.
    """

    /// A plan for another system: what the model copies the shape of.
    static let planExample = #"""
    {"subject":"flow","unit":"order","start":"tap","end":"receipt",
     "rootNote":"{dial:its watchers:} stock low » hold new orders · a refund » reopen the order",
     "lanes":[{"id":"order","name":"an order","colour":"blue","boxes":["CartService","OrderService","PaymentService"]},
              {"id":"store","name":"the store","colour":"green","boxes":["StockService","CatalogService","SearchService"]},
              {"id":"shared","name":"the chain","colour":"orange","beside":true,"boxes":["MailService","BillingService"]}],
     "duties":{"shop":"the till in a terminal: sell, refund, count","Shop.app":"a window per register; a page reads what it shows","ShopAppRoot":"the app's own root: windows, menus, the runtime it starts","ThemeService":"light or dark, the accent, this Mac's fonts","ShopRoot":"starts the services, keeps a relay to each, installs two watchers","CartService":"what a customer picked, priced as they pick it","OrderService":"turns a cart into an order and walks it to paid","PaymentService":"charges the card and says whether it cleared","StockService":"what is on the shelf and what is promised","CatalogService":"every product, its price and its photos","SearchService":"the products' words, indexed as they change","MailService":"the outbox: receipts and notices, sent in order","BillingService":"invoices, refunds, the card on file"},
     "walk":[{"from":"shop","to":"ShopRoot","label":"sell"},{"from":"ShopAppRoot","to":"ShopRoot","label":"boot · open"},{"from":"ShopRoot","to":"CartService","label":"route"},{"from":"CartService","to":"OrderService","label":"place"},{"from":"OrderService","to":"PaymentService","label":"charge"},{"from":"PaymentService","to":"Stripe","label":"capture"},{"from":"OrderService","to":"StockService","label":"reserve"},{"from":"OrderService","to":"MailService","label":"receipt"}],
     "externals":[{"name":"Stripe","under":"PaymentService","what":"cards and payouts"},{"name":"Postgres","under":"StockService","what":"the shelves' rows"}]}
    """#

    /// Whether `text` repeats the worked examples' words, two of them in a row: a model copying a duty or a note rather
    /// than reading the code. Short words and the plate's own common words do not count.
    static func echoes(_ text: String) -> Bool { !pairs(text).isDisjoint(with: examplePairs) }

    private static let examplePairs: Set<String> = {
        var said: [String] = []
        if let plan = try? JSONDecoder().decode(PlatePlan.self, from: Data(planExample.utf8)) {
            said += Array(plan.duties.values) + plan.lanes.compactMap(\.note) + [plan.rootNote].compactMap { $0 } + plan.externals.compactMap(\.what)
        }
        if let spec = try? JSONDecoder().decode(PlateSpec.self, from: Data(example.utf8)) {
            said += spec.nodes.compactMap(\.duty) + [spec.title, spec.subtitle, spec.legend ?? "", spec.heading ?? ""]
        }
        return said.reduce(into: Set<String>()) { $0.formUnion(pairs($1)) }
    }()

    private static func pairs(_ text: String) -> Set<String> {
        let common: Set<String> = ["the", "and", "its", "every", "what", "with", "from", "into", "that", "this", "each", "one", "for", "until",
                                   "when", "dial", "gold", "are", "was", "has", "per", "all", "own", "says", "line"]
        let words = text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 2 && !common.contains($0) }
        return Set(zip(words, words.dropFirst()).map { "\($0) \($1)" })
    }

    static var planSystem: String { planRules + "\n\nA plan for another system, to copy the shape of and never the names or the words:\n" + planExample }

    static var planReviseSystem: String {
        planRules + "\n\nYou are fixing a plan you wrote, after its plate was composed, drawn and measured. Keep everything the findings do not name; make the fewest changes that clear every finding (move a box to another lane, drop a step of the walk, shorten a duty). Answer with the whole plan, fixed."
    }

    static func revise(_ plan: PlatePlan, findings: [PlateFinding]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(plan)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "The plan you wrote:\n\(json)\n\nWhat the composed plate measured:\n" + findings.prefix(16).map { "- " + $0.sentence }.joined(separator: "\n")
            + "\n\nWrite the whole plan again, fixed."
    }

    static let planSchema: Data = {
        let text: [String: Any] = ["type": "string"]
        let colour: [String: Any] = ["type": "string", "enum": PlateColour.allCases.map(\.rawValue)]
        let lane: [String: Any] = ["type": "object", "required": ["id", "name", "colour", "boxes"], "properties": [
            "id": text, "name": text, "colour": colour, "beside": ["type": "boolean"], "note": text, "boxes": ["type": "array", "items": text]]]
        let step: [String: Any] = ["type": "object", "required": ["from", "to"], "properties": ["from": text, "to": text, "label": text]]
        let external: [String: Any] = ["type": "object", "required": ["name", "under"], "properties": ["name": text, "under": text, "what": text]]
        let plan: [String: Any] = ["type": "object", "required": ["unit", "start", "end", "lanes", "duties", "walk"], "properties": [
            "subject": text, "unit": text, "start": text, "end": text, "rootNote": text,
            "lanes": ["type": "array", "items": lane], "duties": ["type": "object", "additionalProperties": text],
            "walk": ["type": "array", "items": step], "externals": ["type": "array", "items": external]]]
        return (try? JSONSerialization.data(withJSONObject: plan, options: [.sortedKeys])) ?? Data("{}".utf8)
    }()

    static var draftSystem: String {
        rules + "\n\nA plate of another system, to copy the shape of and never the names:\n" + example
    }

    static var reviseSystem: String {
        rules + "\n\nYou are fixing a plate you wrote, after it was drawn and measured. Keep every id and everything the findings do not name; make the fewest changes that clear every finding. Answer with the whole spec, fixed."
    }

    static func draft(ask: String?, brief: String?, project: String, sources: PlateSources) -> String {
        var parts: [String] = []
        if let ask, !ask.isEmpty { parts.append("The person asked: \"\(ask)\"") }
        if let brief, !brief.isEmpty { parts.append("What to draw: \(brief)") }
        parts.append("The project is \(project).")
        if !sources.digest.isEmpty { parts.append("What its sources say (\(sources.files) files read):\n\(sources.digest)") }
        parts.append("Write the plate's spec, for this project, in this project's own names.")
        return parts.joined(separator: "\n\n")
    }

    /// What a brief asks of a plate drawn before.
    static func change(_ spec: PlateSpec, brief: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(spec)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "The spec of a plate drawn before:\n\(json)\n\nWhat to change: \(brief)\n\nWrite the whole spec again, changed as asked and nothing else."
    }

    static func revise(_ spec: PlateSpec, findings: [PlateFinding]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(spec)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "The spec you wrote:\n\(json)\n\nWhat the plate measured:\n" + findings.prefix(16).map { "- " + $0.sentence }.joined(separator: "\n")
            + "\n\nWrite the whole spec again, fixed."
    }

    /// The keys, as JSON Schema: what the host shows the model beside the example.
    static let schema: Data = {
        let text: [String: Any] = ["type": "string"]
        let colour: [String: Any] = ["type": "string", "enum": PlateColour.allCases.map(\.rawValue)]
        let lane: [String: Any] = ["type": "object", "required": ["id", "name", "colour"], "properties": [
            "id": text, "name": text, "colour": colour, "columns": ["type": "integer"], "beside": ["type": "boolean"]]]
        let node: [String: Any] = ["type": "object", "required": ["id", "lane", "name"], "properties": [
            "id": text, "lane": text, "name": text, "duty": text, "code": text,
            "kind": ["type": "string", "enum": PlateNodeKind.allCases.map(\.rawValue)], "colour": colour,
            "column": ["type": "integer"], "span": ["type": "integer"], "under": text]]
        let edge: [String: Any] = ["type": "object", "required": ["from", "to"], "properties": [
            "from": text, "to": text, "label": text, "number": ["type": "integer"],
            "style": ["type": "string", "enum": PlateStroke.allCases.map(\.rawValue)], "colour": colour, "both": ["type": "boolean"]]]
        let spec: [String: Any] = ["type": "object", "required": ["caption", "title", "subtitle", "lanes", "nodes", "edges"], "properties": [
            "caption": text, "title": text, "subtitle": text, "heading": text, "machine": text, "tag": text, "legend": text,
            "lanes": ["type": "array", "items": lane], "nodes": ["type": "array", "items": node], "edges": ["type": "array", "items": edge]]]
        return (try? JSONSerialization.data(withJSONObject: spec, options: [.sortedKeys])) ?? Data("{}".utf8)
    }()
}
