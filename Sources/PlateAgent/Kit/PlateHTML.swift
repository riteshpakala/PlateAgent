import Foundation

/// Text from a spec, made safe to place in the page, and the legend's two marks: `**word**` bright and
/// `{gold:words}` (any plate colour) in that colour.
enum PlateHTML {
    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// A legend's text as the page shows it.
    static func legend(_ text: String) -> String {
        var html = escape(text)
        while let open = html.range(of: "**"), let close = html.range(of: "**", range: open.upperBound..<html.endIndex) {
            html.replaceSubrange(open.lowerBound..<close.upperBound, with: "<b>" + html[open.upperBound..<close.lowerBound] + "</b>")
        }
        for colour in PlateColour.allCases {
            let marker = "{\(colour.rawValue):"
            while let open = html.range(of: marker), let close = html.range(of: "}", range: open.upperBound..<html.endIndex) {
                html.replaceSubrange(open.lowerBound..<close.upperBound,
                                     with: "<span style=\"color:\(colour.hex)\">" + html[open.upperBound..<close.lowerBound] + "</span>")
            }
        }
        return html
    }

    /// A number as SVG writes it: whole when it is whole, one decimal otherwise.
    static func n(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}
