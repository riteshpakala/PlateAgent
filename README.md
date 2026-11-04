# PlateAgent

Editorial plates in the Rao plate style, shipped as a [Granite](https://github.com/riteshpakala/Granite) agent
package, in two forms:

- **An infographic of anything**: inspirational quotes, a poem or a creative piece, how something works, a process, a
  comparison, a handful of figures. The app's own model writes it as blocks (quotes, cards, steps, lists, figures, a
  flow of stops, a simple drawing) and the kit sets them on a grid under the plates' header.
- **An architecture plate of a project**: a call names the folders a system lives in; the package reads the code's
  graph off them, the model plans what the plate says, the package composes it and the kit lays it out.

Either way WebKit measures it and the model revises until it measures clean. The plate is written as a PNG at 2x,
which carries the spec it was drawn from.

It is the process behind Craft's README plates ([`flow.png`](https://github.com/riteshpakala/Craft)), made an
agent: the taste lives in the kit, the judgment in a loop of drawing and measuring, and the model only ever says
what the plate means.

## How an app finds it

PlateAgent is a `GraniteAgentPackage`, and it carries a record in its binary:

```swift
@used @section("__DATA_CONST,__granite")
let plateRecord: GraniteRoster.Record = { GraniteRoster.record(PlateAgent.self) }
```

An app that links the package finds it through Granite's roster, imports nothing from it, and offers it what it
has beside the JSON: its folder, the person's ask, a line of progress it shows, and the model it has loaded.

```swift
let input = Data(#"{"sources": ["Sources/App/Services"], "brief": "a turn, through the services"}"#.utf8)
let answer = try await GraniteRoster.discovered().package("plate")?.perform(input, host: AgentHost(
    directory: project.path, ask: request, model: AppModel(session), note: { line in agentMap.say(line) }))
// {"path": "/…/docs/README_Assets/one-turn-every-service.png", "paths": [… .png], "width": 3200, …}
```

[Craft](https://github.com/riteshpakala/Craft) does this: a request that says `$plate` requires the agent, the
package's `guide` rides the turn's prompt, and the call shows on Craft's agent map as `plate-1`, its notes under it.

## What a call takes and answers

| Field | | |
|---|---|---|
| `brief` | optional | what the person asked for, when the ask does not say it: the path the numbers walk, what to put first; never a guess at the architecture, which the package reads off the code |
| `sources` | optional | the folders or files the plate is drawn from, relative to `directory`; the folder itself when left out |
| `spec` | optional | a plate's PNG from an earlier call (or a spec's JSON): drawn again with no draft; with `brief`, changed as it asks |
| `output` | optional | where to write the PNG; `docs/README_Assets/<title>.png` (then `docs/`, then the folder) when left out |
| `rounds` | optional | how many times the model may fix what the plate measured; 3 when left out |
| `form` | optional | `infographic` (anything: quotes, a creative piece, an explanation, a process, figures) or `architecture` (a project's flow from its code); left out, sources that hold code are drawn as their architecture and everything else as an infographic |
| `directory` | the host's | the folder the host works in; a host fills it and does not show it to a model |

The answer is a `PlateResult`: the PNG and the spec written, as absolute paths, the PNG's size, the rounds it
took, what the last round still found (one sentence each), the title, its `form`, and how many lanes, boxes and
arrows (an architecture) or blocks (an infographic) it has. When findings are left, `note` tells the calling model
the call is done: drawing again with the same brief draws the same plate. A calling model that reads findings
otherwise calls again, rewording its brief, until its turn runs out.

## An infographic of anything

```swift
let input = Data(#"{"form": "infographic", "brief": "five inspirational quotes on starting and finishing"}"#.utf8)
```

The model writes a header (caption, title, subtitle, and an optional heading and machine line over the blocks) and
two to nine blocks in reading order, on one to three columns; a block may span more than one, and no row is left part empty (the block before a gap widens to fill it).

| Kind | What it holds | Drawn as |
|---|---|---|
| `quote` | `text`, and `by` only when the person named that speaker | the words large, between gold marks, who said them in small capitals |
| `card` | `title` and `text` | a heading and a few lines |
| `steps` | `title` and `items` | numbered on gold rings |
| `list` | `title` and `items` | lines on coloured dots |
| `stat` | `figure` and `title` | the figure in the title's silver, what it measures under it |
| `flow` | `title` and `items` | stops joined by arrows: a process, a cycle, a path |
| `drawing` | `paths`: SVG path data on a 100 × 100 square, and `title` | outlined strokes in the block's colour; nothing but path data reaches the page |

Each block takes a plate colour (gold, blue, green, orange, violet, red, or dial for a quiet one) on its bar. The
page fits its blocks: it is as tall as the card, the tag at its foot. The findings an infographic hears are its
header's widths, what a plate holds (characters, lines, blocks), a plate too tall to read as one picture, and words
copied from the prompt's example, which is a bakery's. A title wider than the plate is drawn whole and smaller, down
to 70% of its size, never cut (a local model asked to shorten one often answers the same spec), and a revision that
changes nothing ends the rounds.

A quote is never credited to someone the person did not name. A local model does not know who said a line: asked
for quotes, it puts real names on words they never said, or makes names up. So the plate keeps a quote's `by` only
when the person named that speaker (in their ask, or in `brief` on a call with no ask) or a source file does, and
draws any other quote with no name, telling the model so it can fix what its legend says of the lines. Inside an
app the brief is the calling model's words, and it invents speakers too, so it names no one there. For quotes by
real people, name them in the ask:

```
Put these on a $plate: Lao Tzu, "A journey of a thousand miles begins with a single step." Socrates, "The unexamined life is not worth living."
```

## How an architecture plate is made

| Step | Whose | What |
|---|---|---|
| Read | the package | `sources` as a digest: a folder's tree, and of each file its opening comment, its type lines, its Granite declarations and its functions, capped |
| Read the graph | the package | the parts (a folder named for its type), who refers to whom and what one calls on the other, their operations in the order they declare their events, their agents; the front ends (the manifest's executables, an app as `<Package>.app`), the root that holds the parts and a service a front end holds; what they import |
| Plan | the host's model | a few hundred tokens: the lanes and which parts sit in each, a duty for every box, the walk the numbers take, what is across a wire, the header and the legend |
| Compose | the package | the spec from the plan and the graph: each box's duty fitted to two lines of its box, its operations as its code line, its agents hung under it; the walk numbered (two ways into one box share a number), each agent's run, each external's wire, the code's other references labelled with what is called |
| Check | the package | ids that name nothing, text past what a box holds, a walk that skips a number |
| Grid | the package | each lane's boxes in columns: a column of agents and externals narrower, a gap a labelled arrow crosses as wide as its label, a column as wide as its longest code line |
| Measure | WebKit | what each box says, at its width, so each row is as tall as its tallest box |
| Lay out | the package | lanes stacked, boxes placed, arrows routed (direct, an elbow, round a gutter, under the row, round a box), numbers and labels placed clear |
| Render | WebKit | the page settled to the header's rhythm, measured, and exported at 2x |
| Measure again | WebKit | every text wider than its box, every two things drawn over each other, everything past the edge |
| Revise | the host's model | the findings, as sentences, and the plan back, fixed; until it measures clean or the rounds are spent |

The best round is written. Nothing on a plate is placed by the model, and it never writes an arrow the code does
not have: a local coder plans a good plate in a minute, and it is never asked to place forty labels. Sources with
no code graph (a folder of notes) are an infographic of what they say, unless the call asks for `form: architecture`,
when the model drafts the lanes whole.

## The kit

The page is 1600 wide, drawn at 2x. The header: the RR seal, the caption in spaced capitals, the title in
Playfair Display italic with a platinum gradient, the subtitle, all held to one rhythm (the seal's ink 70 px in,
the title's 174 px down, the card 54 px under the subtitle). The card holds the lanes: tinted bands named in
small capitals at their feet.

- **A service** is a card with a colour bar: its name, its duty, its code line in Menlo.
- **An agent** is a dashed gold box: something that runs on a model, hung under the box that runs it.
- **An external** is a dashed box: a process across a wire, a store, a framework.
- **Solid** arrows are calls, in the colour of the box they leave; **dashed gold** is an agent's run and what it
  writes; **dashed grey** is observing and calling back, or a process across a wire.
- **Numbers** in gold circles walk one path, end to end.

The colours are the plates': gold `#c7a659`, blue `#5e8fda`, green `#28a883`, orange `#d8773f`, violet `#a88bd6`,
red `#d9645a`, and two greys. `Tests/PlateAgentTests/Support/Fixture.swift` holds Craft's flow plate as a spec,
and the tests draw it clean at 3200 wide.

## Redraw, or change, without a draft

The PNG carries the spec it was drawn from, in an `iTXt` chunk keyed `plate-spec`, so a call leaves one file in the
project and nothing a build reads. Call again with `spec` set to that PNG and the plate is laid out, measured and
written with no model; add a `brief` ("rename the root to CraftRuntimeRoot", "move the watch to the project lane")
and the host's model makes that change on the spec first.

## Adding a kind of box

A kind is a case of `PlateNodeKind`, its CSS in `PlateKit`, its mark in `PlateCanvas`, and its height rule in
`PlateLayout.height(of:_:)`. The draft's rules (`PlateDraft.rules`) say when a model should use it.

## Nothing on the main thread until a call

The WebKit page and the face are made on the first call (`PlateCompute`). An app that links the package and never
asks for a plate pays nothing.

## Requirements

macOS 26 (WebKit's `WebPage`), Swift 6.4 for the record's `@used` and `@section`. The face is Playfair Display
Italic, bundled under the SIL Open Font License (`Sources/PlateAgent/Resources/OFL.txt`); an app copies the
package's resource bundle (`PlateAgent_PlateAgent.bundle`) beside its executable or into its resources, and set
`PLATE_RESOURCES` to point anywhere else. `PLATE_HTML=<folder>` keeps each round's page to open in a browser.
`swift test` draws the flow plate in WebKit and checks it measures clean.
