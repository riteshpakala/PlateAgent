import Foundation

extension PlateSpec {
    /// The head of the card the lanes sit in.
    var headingText: String { heading?.trimmed.nonEmpty ?? "The flow, end to end" }

    /// The legend under the lanes: the model's, or one said from the strokes and numbers the plate uses.
    var legendText: String {
        if let legend = legend?.trimmed.nonEmpty { return legend }
        let styles = Set(edges.map { $0.style ?? .solid })
        var parts: [String] = []
        if styles.contains(.solid) { parts.append("solid arrows are calls, in the colour of the box they leave") }
        if styles.contains(.dashedGold) { parts.append("{gold:dashed gold} is an agent’s run and what it writes") }
        if styles.contains(.dashedGrey) { parts.append("dashed grey is a box observing another and calling back, or a process across a wire") }
        var text = "Each box is a part of the system; its line says what it is responsible for."
        if !parts.isEmpty { text += " " + parts.joined(separator: "; ").capitalizedFirst + "." }
        if edges.contains(where: { $0.number != nil }) { text += " The numbers walk one path." }
        return text
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
