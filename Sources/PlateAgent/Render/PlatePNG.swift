import Foundation

/// The spec a plate was drawn from, carried inside its PNG: an `iTXt` chunk keyed `plate-spec`, before `IEND`. One
/// file is the picture and what redraws it, so a project gains a PNG and nothing a build might read.
enum PlatePNG {
    static let keyword = "plate-spec"
    private static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    /// `png` with `text` in an uncompressed `iTXt` chunk before its end.
    static func embedding(_ text: String, in png: Data) -> Data {
        guard png.starts(with: signature), let end = chunkOffset(of: "IEND", in: png) else { return png }
        var body = Data(keyword.utf8)
        body.append(contentsOf: [0, 0, 0, 0, 0])   // keyword end, not compressed, method, no language, no translation
        body.append(Data(text.utf8))
        var chunk = Data()
        chunk.append(bigEndian(UInt32(body.count)))
        let typed = Data("iTXt".utf8) + body
        chunk.append(typed)
        chunk.append(bigEndian(crc32(typed)))
        var out = png
        out.insert(contentsOf: chunk, at: end)
        return out
    }

    /// The text a PNG carries under `plate-spec`, if it carries one.
    static func embedded(in png: Data) -> String? {
        guard png.starts(with: signature) else { return nil }
        var offset = 8
        let bytes = [UInt8](png)
        while offset + 12 <= bytes.count {
            let length = Int(UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3]))
            let type = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
            let start = offset + 8, end = start + length
            guard end + 4 <= bytes.count else { return nil }
            if type == "iTXt" {
                let body = Array(bytes[start..<end])
                if let nul = body.firstIndex(of: 0), String(decoding: body[..<nul], as: UTF8.self) == keyword {
                    // Past the keyword: compression flag and method, then the language and translated keyword, each ended by a 0.
                    var i = nul + 3
                    for _ in 0..<2 { while i < body.count, body[i] != 0 { i += 1 }; i += 1 }
                    return i <= body.count ? String(decoding: body[i...], as: UTF8.self) : nil
                }
            }
            if type == "IEND" { return nil }
            offset = end + 4
        }
        return nil
    }

    private static func chunkOffset(of type: String, in png: Data) -> Int? {
        let bytes = [UInt8](png)
        var offset = 8
        while offset + 12 <= bytes.count {
            let length = Int(UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3]))
            if String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self) == type { return offset }
            offset += 12 + length
        }
        return nil
    }

    private static func bigEndian(_ value: UInt32) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }

    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in data { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}
