import Foundation

/// Observed Intercode environment/holder variant. Reject unknown field layouts
/// instead of allowing them to shift the holder fields silently.
struct RegionalEnvironment: Equatable {
    let version: Int
    let network: Int
    let issuer: Int
    let expiryDay: Int
    let birthDate: String?
    let personalization: Int?
    let commercialCode: Int?
    var versionLabel: String { "Intercode \(version >> 3 == 0 ? 1 : 2).\(version & 7)" }
    var expiryLabel: String { Self.dayLabel(expiryDay) }
    var personalizationLabel: String {
        switch personalization.map({ $0 & 3 }) {
        case 0: return "Anonyme"
        case 1: return "Déclarative"
        case 2: return "Nominative"
        case 3: return "Propre au réseau"
        default: return "Non renseignée"
        }
    }
    static func dayLabel(_ day: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let epoch = calendar.date(from: DateComponents(year: 1997, month: 1, day: 1))!
        let date = calendar.date(byAdding: .day, value: day, to: epoch)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02d/%02d/%04d", parts.day!, parts.month!, parts.year!)
    }
    static func decode(_ hex: String) -> RegionalEnvironment? {
        guard !hex.isEmpty, hex.count.isMultiple(of: 2), hex.count <= 512,
              hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        let bits = hex.flatMap { character -> [UInt8] in
            let v = UInt8(String(character), radix: 16)!
            return (0..<4).reversed().map { (v >> $0) & 1 }
        }
        var offset = 0
        func read(_ n: Int) -> Int? {
            guard offset + n <= bits.count else { return nil }
            var v = 0
            for bit in bits[offset..<offset+n] { v = v << 1 | Int(bit) }
            offset += n; return v
        }
        guard let version = read(6), version >> 3 <= 1,
              read(7) == 7, let network = read(24), let issuer = read(8), let expiry = read(14), expiry > 0, expiry < 16383,
              let holder = read(8), holder & ~0x82 == 0 else { return nil }
        var birth: String?
        if holder & 2 != 0 {
            guard read(2) == 1, let bcd = read(32) else { return nil }
            let digits = String(format: "%08X", bcd)
            guard digits.allSatisfy(\.isNumber), let year = Int(digits.prefix(4)),
                  let month = Int(digits.dropFirst(4).prefix(2)), let day = Int(digits.suffix(2)),
                  year >= 1900, year <= 2100 else { return nil }
            var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
            let parts = DateComponents(year: year, month: month, day: day)
            guard let date = cal.date(from: parts), cal.dateComponents([.year, .month, .day], from: date) == parts else { return nil }
            birth = String(format: "%02d/%02d/%04d", day, month, year)
        }
        var personalization: Int?
        var commercial: Int?
        if holder & 128 != 0 {
            guard let mask = read(12), mask & ~9 == 0 else { return nil }
            if mask & 1 != 0 { guard let v = read(4) else { return nil }; personalization = v }
            if mask & 8 != 0 { guard let v = read(6) else { return nil }; commercial = v }
        }
        guard bits.dropFirst(offset).allSatisfy({ $0 == 0 }) else { return nil }
        return .init(version: version, network: network, issuer: issuer, expiryDay: expiry,
                     birthDate: birth, personalization: personalization, commercialCode: commercial)
    }
}

extension RegionalCardCapture {
    var regionalEnvironment: RegionalEnvironment? {
        guard transportRegion != .mobib else { return nil }
        return ticketingRecords(sfi: 7, path: "20002001")?[1].flatMap(RegionalEnvironment.decode)
    }
}
