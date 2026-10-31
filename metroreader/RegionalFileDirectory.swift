import Foundation

/// Calypso public GET DATA EF LIST (tag C0), with explicit BER bounds checks.
/// Only descriptors returned by the card become extra read locations.
enum RegionalFileDirectory {
    static func fileIDs(_ data: Data) -> [UInt16]? {
        let bytes = Array(data)
        guard bytes.count >= 2, bytes[0] == 0xC0 else { return nil }
        var offset = 2
        let length: Int
        if bytes[1] < 128 {
            length = Int(bytes[1])
        } else {
            let size = Int(bytes[1] & 127)
            guard size > 0, size <= 2, bytes.count >= 2 + size else { return nil }
            length = bytes[2..<2 + size].reduce(0) { $0 << 8 | Int($1) }
            offset += size
        }
        guard length.isMultiple(of: 8), bytes.count == offset + length else { return nil }
        var files: [UInt16] = []
        for index in stride(from: offset, to: offset + length, by: 8) {
            guard bytes[index] == 0xC1, bytes[index + 1] == 6,
                  [1, 2, 4, 8, 9].contains(Int(bytes[index + 5])) else { return nil }
            let id = UInt16(bytes[index + 2]) << 8 | UInt16(bytes[index + 3])
            guard id != 0, !files.contains(id) else { return nil }
            files.append(id)
        }
        return files
    }
}
