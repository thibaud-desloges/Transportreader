import Foundation

/// Partial AMC decoding from ADCET's public field descriptions and the observed
/// common-AMC layout. Does not authenticate the signature or claim service usage.
struct RegionalAMC {
    struct Sector: Identifiable {
        let id: Int
        let keyReference: Int
        let value: UInt32
        var name: String {
            switch id {
            case 1: return "Fiscalité"
            case 2: return "Travail et social"
            case 3: return "Santé"
            case 4: return "Transports publics"
            case 5: return "État civil et citoyenneté"
            case 6: return "Relations avec les élus"
            case 7: return "Services scolaires, sportifs et culturels"
            case 8: return "Économie et urbanisme"
            case 9: return "Voirie et polices spéciales"
            case 10: return "Relations avec les usagers"
            case 11: return "Services aux agents"
            case 12: return "Vie étudiante"
            case 13: return "Fidélité et commerce"
            case 14: return "Mobilité · MaaS"
            case 20: return "Services à la personne"
            case 21: return "Transports privés"
            case 22: return "Paiements"
            case 23: return "Réseaux sociaux"
            case 24: return "Sport, culture et loisirs"
            case 25: return "Programme de fidélité"
            case 15...19, 26...30: return "Secteur réservé"
            default: return "Service spécifique non nommé"
            }
        }
    }
    let issuerReference: Int
    let version: Int
    let scope: Int
    let encodedDate: String
    let signatureKeyReference: Int
    let sectors: [Sector]
    let signatureByteCount: Int
    var issuerName: String? { issuerReference == 0xE002 ? "Gemalto" : nil }

    static func decode(_ bytes: [UInt8]) -> RegionalAMC? {
        guard bytes.count >= 77, bytes.count <= 4096 else { return nil }
        func number(_ start: Int, _ count: Int) -> Int {
            bytes[start..<start+count].reduce(0) { $0 << 8 | Int($1) }
        }
        let count = Int(bytes[12]), end = 13 + count * 8
        guard bytes[2] == 1, number(3, 3) == 0x250E00, (1...35).contains(count),
              end + 64 <= bytes.count, bytes[(end+64)...].allSatisfy({ $0 == 0 }) else { return nil }
        let date = bytes[6..<10]
        guard date.allSatisfy({ $0 >> 4 <= 9 && $0 & 15 <= 9 }) else { return nil }
        let dateText = date.map { String(format: "%02X", $0) }.joined()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"; formatter.isLenient = false
        guard let parsedDate = formatter.date(from: dateText), formatter.string(from: parsedDate) == dateText else { return nil }
        formatter.dateFormat = "dd/MM/yyyy"
        var sectors: [Sector] = []
        var seen = Set<Int>()
        for index in 0..<count {
            let start = 13 + index * 8
            let id = number(start, 2)
            guard id > 0, seen.insert(id).inserted else { return nil }
            sectors.append(.init(id: id, keyReference: number(start+2, 2), value: UInt32(number(start+4, 4))))
        }
        return .init(issuerReference: number(0, 2), version: Int(bytes[2]), scope: number(3, 3),
                     encodedDate: formatter.string(from: parsedDate), signatureKeyReference: number(10, 2),
                     sectors: sectors, signatureByteCount: 64)
    }
}

extension RegionalCardCapture {
    var regionalAMC: RegionalAMC? {
        // Exact absolute path or application-relative path scoped to the AMC AID.
        var chunks: [Int: [UInt8]] = [:]
        for exchange in exchanges where ["9000", "6282"].contains(exchange.statusWord) {
            let absolutes = ["READ BINARY PATH 22002203 / ", "READ BINARY PATH 32003203 / "]
            let relatives = ["READ BINARY PATH APP 2203 / ", "READ BINARY PATH APP 3203 / "]
            let prefix: String
            if let absolute = absolutes.first(where: { exchange.operation.hasPrefix($0) }), ["334D54522E494341", "A000000291D25008009301"].contains(exchange.application ?? selectedApplication) { prefix = absolute }
            else if let relative = relatives.first(where: { exchange.operation.hasPrefix($0) }), exchange.application == "A000000291D25008009301" { prefix = relative }
            else { continue }
            guard let token = exchange.operation.dropFirst(prefix.count).split(separator: " ").first,
                  let offset = Int(token), offset >= 0, offset < 4096,
                  exchange.response.count.isMultiple(of: 2), exchange.response.count <= 8192 else { return nil }
            var bytes: [UInt8] = []
            var index = exchange.response.startIndex
            while index < exchange.response.endIndex {
                let next = exchange.response.index(index, offsetBy: 2)
                guard let byte = UInt8(exchange.response[index..<next], radix: 16) else { return nil }
                bytes.append(byte); index = next
            }
            if let previous = chunks[offset], previous != bytes { return nil }
            chunks[offset] = bytes
        }
        var bytes: [UInt8] = []
        for offset in chunks.keys.sorted() {
            guard offset <= bytes.count, offset + chunks[offset]!.count <= 4096 else { return nil }
            for (index, byte) in chunks[offset]!.enumerated() {
                if offset+index < bytes.count {
                    guard bytes[offset+index] == byte else { return nil }
                } else { bytes.append(byte) }
            }
        }
        return RegionalAMC.decode(bytes)
    }
}
