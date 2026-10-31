import Foundation

/// Read only ISO application directory and Calypso linked-application objects.
/// Unknown primitive values are never searched for apparent AID byte patterns.
enum RegionalApplicationDirectory {
    static func identifiers(_ data: Data) -> [String]? {
        var found: [String] = []
        func parse(_ bytes: [UInt8], depth: Int) -> Bool {
            guard depth <= 8 else { return false }
            var offset = 0
            while offset < bytes.count {
                let first = bytes[offset]
                offset += 1
                // ISO directory records may end in padding.
                if first == 0 || first == 255 {
                    return bytes[(offset - 1)...].allSatisfy { $0 == 0 || $0 == 255 }
                }
                var tag = Int(first)
                if first & 31 == 31 {
                    var count = 0
                    while true {
                        guard offset < bytes.count, count < 2 else { return false }
                        let next = bytes[offset]; offset += 1; count += 1
                        tag = tag << 8 | Int(next)
                        if next & 128 == 0 { break }
                    }
                }
                guard offset < bytes.count else { return false }
                let lead = bytes[offset]; offset += 1
                var length = Int(lead)
                if lead & 128 != 0 {
                    let count = Int(lead & 127)
                    guard (1...2).contains(count), offset + count <= bytes.count else { return false }
                    length = 0
                    for byte in bytes[offset..<offset + count] { length = length << 8 | Int(byte) }
                    offset += count
                }
                guard offset + length <= bytes.count else { return false }
                let value = Array(bytes[offset..<offset + length]); offset += length
                if tag == 0x4F || tag == 0x84 {
                    guard (5...16).contains(value.count) else { return false }
                    let aid = value.map { String(format: "%02X", $0) }.joined()
                    if !found.contains(aid) { found.append(aid) }
                } else if first & 32 != 0 || tag == 0xD0 {
                    guard parse(value, depth: depth + 1) else { return false }
                }
            }
            return true
        }
        return parse(Array(data), depth: 0) ? found : nil
    }
}
