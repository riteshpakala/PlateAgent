import Foundation

/// The plate as a page: the Rao plates' CSS (Craft's docs/README_Assets/src/plates.py, ported as it is), the
/// header (seal, caption, title, subtitle), the card the lanes sit in, the body the layout drew, and the foot.
/// What makes a plate look like one lives here and in `PlateCanvas`; the layout only says where.
enum PlateKit {
    /// The page's face and seal, as data the page carries: nothing is fetched, so the page is the same anywhere.
    struct Faces: Sendable {
        let font: String
        let mark: String
    }

    static func page(caption: String, title: String, subtitle: String, body: String, tag: String, height: Double, faces: Faces) -> String {
        let n = PlateHTML.n, esc = PlateHTML.escape
        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        \(fontFace(faces))
        html, body { margin: 0; width: \(n(PlatePalette.width))px; height: \(n(height))px; overflow: hidden; }
        body { position: relative; font-family: "Playfair", Georgia, serif; font-style: italic; color: #a29f97; font-variant-numeric: lining-nums;
               background: radial-gradient(ellipse 90% 100% at 22% 20%, #20201c 0%, #191917 45%, #121211 100%); }
        .mark { position: absolute; left: 68.8px; top: 69.3px; width: 46.2px; }
        .caption { position: absolute; left: 145.8px; top: 78px; letter-spacing: .3em; font-size: 15px; color: #8b8a84; }
        .title { position: absolute; left: 39.5px; padding-left: 40px; top: 162px; font-size: 104px; line-height: 1; font-weight: 500; letter-spacing: -.005em; padding-right: 30px; padding-bottom: 32px;
                 background: linear-gradient(100deg, #8d9097 0%, #c8cad0 35%, #f2f3f6 58%, #b6b9c1 100%);
                 -webkit-background-clip: text; background-clip: text; color: transparent; white-space: nowrap; }
        .sub { position: absolute; left: 69px; top: 280px; font-size: 32px; color: #9b9991; white-space: nowrap; }
        svg { position: absolute; left: 0; top: 0; }
        \(components)
        .tag { position: absolute; right: 70px; top: \(n(height - 52))px; font-size: 18px; color: #8b8a84; }
        </style></head><body>
        <img class="mark" src="\(faces.mark)">
        <div class="caption">\(esc(caption))</div>
        <div class="title" data-id="title">\(esc(title))</div>
        <div class="sub" data-id="subtitle">\(esc(subtitle))</div>
        \(body)
        <div class="tag">\(esc(tag))</div>
        \(settleScript)
        </body></html>
        """
    }

    /// A page that holds only what the measure pass sizes: each box at its width, the legend at its width. The
    /// same CSS as the plate, so what it measures is what the plate draws.
    static func measurePage(boxes: String, faces: Faces) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><style>
        \(fontFace(faces))
        html, body { margin: 0; width: \(PlateHTML.n(PlatePalette.width))px; }
        body { position: relative; font-family: "Playfair", Georgia, serif; font-style: italic; color: #a29f97; font-variant-numeric: lining-nums; }
        \(components)
        .m { position: relative !important; left: 0 !important; top: 0 !important; height: auto !important; margin-bottom: 8px; }
        .ext.m, .agt.m { display: block; }
        </style></head><body>\(boxes)</body></html>
        """
    }

    /// The card the lanes sit in, with its head: a gold dot, the step, the heading, and small capitals on the right.
    static func card(_ box: PlateBox, heading: String, machine: String?) -> String {
        let n = PlateHTML.n, esc = PlateHTML.escape
        let right = machine.map { "<span class=\"machine\">\(esc($0.uppercased()))</span>" } ?? ""
        return "<div class=\"card\" style=\"left:\(n(box.x))px; top:\(n(box.y))px; width:\(n(box.w))px; height:\(n(box.h))px\">"
            + "<div class=\"head\"><span><i class=\"dot\" style=\"background:\(PlateColour.gold.hex)\"></i><b><span class=\"step\">1</span>\(esc(heading))</b></span>\(right)</div></div>"
    }

    private static func fontFace(_ faces: Faces) -> String {
        "@font-face { font-family: \"Playfair\"; font-style: italic; font-weight: 400 900; src: url(\"\(faces.font)\") format(\"truetype\"), local(\"Playfair Display Italic\"); }"
    }

    /// The boxes, labels, notes and the card, as the plates style them.
    private static let components = """
    .card { position: absolute; box-sizing: border-box; border: 1px solid rgba(255,255,255,.11); border-radius: 14px; background: rgba(255,255,255,.028); padding: 16px 20px; }
    .head { display: flex; justify-content: space-between; align-items: baseline; }
    .head b { font-weight: 400; font-size: 26px; color: #ecebe5; }
    .machine { font-size: 11.5px; letter-spacing: .22em; color: #77756f; white-space: nowrap; }
    .dot { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 10px; transform: translateY(-2px); }
    .step { display: inline-flex; align-items: center; justify-content: center; width: 20px; height: 20px; margin-right: 9px; border: 1.6px solid \(PlateColour.gold.hex);
            border-radius: 50%; font-family: \(PlatePalette.sans); font-style: normal; font-weight: 600; font-size: 12px; color: \(PlateColour.gold.hex); transform: translateY(-1px); flex: none; }
    .wire { position: absolute; font-family: \(PlatePalette.mono); font-style: normal; font-size: 12px; color: #a7a49b; white-space: nowrap; }
    .svcw { background: rgba(26,26,23,.94); padding: 1px 5px; border-radius: 4px; }
    .note { position: absolute; font-size: 16px; line-height: 1.36; color: #a29f97; }
    .note b { font-weight: 400; color: #ecebe5; }
    .lanelab { position: absolute; font-size: 11.5px; letter-spacing: .22em; white-space: nowrap; }
    .node { position: absolute; box-sizing: border-box; padding: 10px 14px 0 20px; display: flex; flex-direction: column; }
    .node b { font-weight: 400; font-size: 19px; color: #ecebe5; line-height: 1.15; white-space: nowrap; }
    .node span { font-size: 14.5px; line-height: 1.3; color: #a29f97; margin-top: 4px; }
    .node code { font-family: \(PlatePalette.mono); font-style: normal; font-size: 11.5px; color: #8b8a84; margin-top: 5px; white-space: nowrap; }
    .agt { position: absolute; box-sizing: border-box; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; padding: 0 8px; }
    .agt b { font-weight: 400; font-size: 17px; color: \(PlateColour.gold.hex); white-space: nowrap; }
    .agt span { font-family: \(PlatePalette.mono); font-style: normal; font-size: 10.5px; color: #a7a49b; margin-top: 3px; white-space: nowrap; }
    .ext { position: absolute; box-sizing: border-box; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; padding: 6px 10px; }
    .ext b { font-weight: 400; font-size: 18px; color: #ecebe5; white-space: nowrap; }
    .ext span { font-family: \(PlatePalette.mono); font-style: normal; font-size: 11px; color: #8b8a84; margin-top: 4px; }
    """
}
