import Foundation

/// Reading a model's JSON loosely: a number written as a string, a boolean as "yes", an element of a list that
/// does not decode dropped rather than the whole list. A local model's JSON is loose; a plate should not be lost
/// to a stray quote.
enum PlateLoose {
    /// A value that decodes, or nothing, never a thrown error: one bad element of a list is dropped alone.
    struct Element<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    static func string<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return text }
        if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return String(number) }
        return nil
    }

    static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return number }
        if let number = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(number) }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return Int(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    static func bool<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Bool? {
        if let flag = try? c.decodeIfPresent(Bool.self, forKey: key) { return flag }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return ["true", "yes", "1"].contains(text.lowercased()) }
        if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return number != 0 }
        return nil
    }

    static func list<K: CodingKey, T: Decodable>(_ c: KeyedDecodingContainer<K>, _ key: K, of type: T.Type) -> [T] {
        ((try? c.decodeIfPresent([Element<T>].self, forKey: key)) ?? nil)?.compactMap(\.value) ?? []
    }

    /// An id made from a name: lowercase letters and digits, words joined by `-`.
    static func slug(_ text: String) -> String {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.joined(separator: "-")
    }
}
