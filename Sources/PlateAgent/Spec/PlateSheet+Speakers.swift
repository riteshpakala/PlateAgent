import Foundation

/// Who a plate's quotes are by: only the speakers the person named.
///
/// PIN: A SPEAKER IS THE PERSON'S, NEVER THE MODEL'S. A local model does not know who said a line: asked for quotes,
/// it puts real names on words they never said ("Maya Angelou") or makes names up ("W. E. Dusin"), and its legend
/// says the quotes are sourced. A rule in the prompt does not stop it, so the plate holds it: a quote keeps its `by`
/// only when the person's ask or the sources name that speaker. Any other is left off the drawn plate, and the model
/// is told, so it fixes what its legend says of the lines.
/// PIN: THE BRIEF IS NOT THE PERSON. When there is an ask, the brief is the calling model's, and a calling model
/// invents speakers there too ("Albert E. Donaldson", "Unknown"); it names a speaker only on a call with no ask.
extension PlateSheet {
    /// The quotes whose speaker nothing the person gave names, one finding each.
    func speakers(named grounds: String) -> [PlateFinding] {
        blocks.enumerated().compactMap { index, block in
            guard block.kind == .quote, let by = block.by, !Self.named(by, in: grounds) else { return nil }
            return PlateFinding(.limit, "block:\(index + 1)",
                                "\(Self.describe(index, block)) credits a speaker the person did not name, so the plate leaves the name off: a plate credits a speaker only when the person did. Leave `by` out, and let the legend say the lines were written for this plate.")
        }
    }

    /// The sheet with only the speakers the person named.
    func attributed(to grounds: String) -> PlateSheet {
        var sheet = self
        for index in sheet.blocks.indices where sheet.blocks[index].kind == .quote {
            if let by = sheet.blocks[index].by, !Self.named(by, in: grounds) { sheet.blocks[index].by = nil }
        }
        return sheet
    }

    /// Whether `grounds` names the speaker: the last word of their name, as a word ("Angelou" for "Maya Angelou",
    /// "Tzu" for "Lao Tzu"); initials name no one.
    static func named(_ by: String, in grounds: String) -> Bool {
        func words(_ text: String) -> [String] { text.lowercased().split { !$0.isLetter }.map(String.init) }
        guard let last = words(by).last(where: { $0.count > 2 }) else { return false }
        return words(grounds).contains(last)
    }
}
