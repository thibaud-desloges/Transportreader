import Foundation

/// Calypso proprietary file information (tag 85, 23 bytes), decoded independently
/// from the field layout documented by Keyple/Keypop. Does not authenticate.
struct RegionalFileHeader: Identifiable, Equatable {
    let path: String
    let recordSize: Int
    let recordCount: Int
    let readAccess: UInt8
    let sharedReference: Int
    var id: String { path }
    var readAccessLabel: String {
        switch readAccess {
        case 0x1F: return "Lecture publique"
        case 0x01: return "Lecture sous PIN"
        case 0x00: return "Lecture interdite"
        case 0x10: return "Session sécurisée requise"
        case 0x14: return "Lecture confidentielle"
        case 0x15: return "Lecture confidentielle et PIN"
        default: return String(format: "Mode d’accès %02X", readAccess)
        }
    }
    var requiresPIN: Bool { readAccess == 0x01 || readAccess == 0x15 }
    static func logicalIdentifier(_ hex: String, legacy: Bool) -> Int? {
        guard decode(hex, path: "") != nil else { return nil }
        return Int(hex.dropFirst((2 + (legacy ? 20 : 21)) * 2).prefix(4), radix: 16)
    }

    static func decode(_ hex: String, path: String) -> RegionalFileHeader? {
        guard hex.count == 50, hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<end], radix: 16) else { return nil }
            bytes.append(byte); index = end
        }
        guard bytes[0] == 0x85, bytes[1] == 23 else { return nil }
        let info = Array(bytes.dropFirst(2))
        guard info[1] == 4, [1, 2, 4, 8, 9].contains(info[2]) else { return nil }
        let binary = info[2] == 1
        return .init(path: path, recordSize: binary ? Int(info[3]) << 8 | Int(info[4]) : Int(info[3]),
                     recordCount: binary ? 1 : Int(info[4]), readAccess: info[5],
                     sharedReference: Int(info[14]) << 8 | Int(info[15]))
    }
}

extension RegionalCardCapture {
    var regionalFileHeaders: [RegionalFileHeader] {
        var headers: [String: RegionalFileHeader] = [:]
        var conflicts = Set<String>()
        let roots = ["334D54522E494341": "", "A0000004040125092001": "2000",
                     "A0000004040225092001": "1000", "A0000004044125092001": "2300",
                     "A000000291A00000019102": "2100", "A000000291D25008009301": "2200"]
        for exchange in exchanges where exchange.statusWord == "9000" {
            let absolute = "SELECT PATH "
            let relative = "SELECT PATH APP "
            var path: String
            if exchange.operation.hasPrefix(relative) {
                guard let root = roots[exchange.application ?? selectedApplication] else { continue }
                path = root + String(exchange.operation.dropFirst(relative.count))
            } else if exchange.operation.hasPrefix(absolute) {
                path = String(exchange.operation.dropFirst(absolute.count))
            } else { continue }
            guard path.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }) else { continue }
            if path.hasPrefix("3F00") { path.removeFirst(4) }
            guard let header = RegionalFileHeader.decode(exchange.response, path: path) else { continue }
            if let previous = headers[path], previous != header { conflicts.insert(path) }
            headers[path] = header
        }
        return headers.values.filter { !conflicts.contains($0.path) }.sorted { $0.path < $1.path }
    }
}
