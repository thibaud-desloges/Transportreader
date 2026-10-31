import Foundation

/// Independent, bounded interpretation of the MOBIB wire layout. References
/// and field offsets: Design/RegionalDecoding.md. Unsupported versions remain raw.
private struct MobibBits {
    let bits: [UInt8]
    var offset = 0
    init?(_ hex: String) {
        guard !hex.isEmpty, hex.count <= 512, hex.count.isMultiple(of: 2),
              hex.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
        bits = hex.flatMap { c in
            let n = UInt8(String(c), radix: 16)!
            return (0..<4).reversed().map { (n >> $0) & 1 }
        }
    }
    mutating func read(_ width: Int) throws -> Int {
        guard (1...24).contains(width), offset + width <= bits.count else { throw Invalid.truncated }
        var value = 0
        for bit in bits[offset..<offset + width] { value = value * 2 + Int(bit) }
        offset += width
        return value
    }
    mutating func skip(_ width: Int) throws {
        guard width >= 0, offset + width <= bits.count else { throw Invalid.truncated }
        offset += width
    }
    enum Invalid: Error { case truncated }
}

struct RegionalMobibEvent: Identifiable, Equatable {
    let id: String
    let header: RegionalEventHeader
    let mode: Int
    let route: Int?
    let location: Int
    let busLocation: Int?
    let sequence: Int?
    let firstStamp: RegionalEventHeader?
    let sourceFile: String
    var modeLabel: String {
        switch mode { case 0, 7: return "Métro"; case 6, 22: return "Tram"; default: return "Bus" }
    }
    /// Public MOBIB dictionary: mode + route + reader stop jointly form a key.
    var placeName: String? {
        mode == 15 && route == 54 && busLocation == 2931 ? "Trinité" : nil
    }
    static func decode(_ hex: String, file: String, record: Int) -> Self? {
        guard hex.count == 96, var b = MobibBits(hex) else { return nil }
        do {
            guard try b.read(6) == 3 else { return nil }
            let day = try b.read(14), minute = try b.read(11)
            guard let header = RegionalEventHeader(day: day, minutes: minute) else { return nil }
            try b.skip(31)
            let fields = try b.read(5)
            var bus: Int?, route: Int?, mode: Int?, location: Int?
            if fields & 1 != 0 { try b.skip(4); bus = try b.read(12) }
            if fields & 2 != 0 { route = try b.read(16) }
            if fields & 4 != 0 { try b.skip(16) }
            if fields & 8 != 0 { try b.skip(16) }
            if fields & 16 != 0 {
                mode = try b.read(5); location = try b.read(17); try b.skip(10)
            }
            let extra = try b.read(6)
            let sequence = extra & 1 != 0 ? try b.read(24) : nil
            if extra & 2 != 0 { try b.skip(16) }
            if extra & 4 != 0 { try b.skip(8) }
            if extra & 8 != 0 { try b.skip(16) }
            var first: RegionalEventHeader?
            if extra & 16 != 0 {
                let firstDay = try b.read(14), firstMinute = try b.read(11)
                guard let stamp = RegionalEventHeader(day: firstDay, minutes: firstMinute) else { return nil }
                first = stamp
            }
            if extra & 32 != 0 { try b.skip(16) }
            try b.skip(21)
            guard let mode, [0, 6, 7, 15, 22].contains(mode), let location else { return nil }
            return .init(id: "\(file):\(record)", header: header, mode: mode, route: route,
                         location: location, busLocation: bus, sequence: sequence,
                         firstStamp: first, sourceFile: file)
        } catch { return nil }
    }
}

struct RegionalMobibTitle: Identifiable, Equatable {
    let id: Int
    let tariff: Int
    let priceCents: Int
    let saleDay: Int?
    let counter: Int?
    /// This is a documented product code, not a name inferred from its price.
    var name: String? { tariff == 0x2803 ? "JUMP 10 voyages" : nil }
    var remainingJourneys: Int? { tariff == 0x2803 ? counter : nil }
    static func decode(_ hex: String, record: Int, counter: Int?) -> Self? {
        guard hex.count == 96, var b = MobibBits(hex) else { return nil }
        do {
            guard try b.read(6) == 4 else { return nil }
            try b.skip(19)
            let tariff = try b.read(14)
            guard tariff > 0 else { return nil }
            try b.skip(50)
            let price = try b.read(16)
            try b.skip(6)
            let fields = try b.read(5)
            if fields & 1 != 0 { try b.skip(5) }
            if fields & 2 != 0 { try b.skip(5) }
            let sale = fields & 4 != 0 ? try b.read(14) : nil
            if let sale, !(1..<0x3FFF).contains(sale) { return nil }
            if fields & 8 != 0 { try b.skip(10) }
            if fields & 16 != 0 { try b.skip(8) }
            try b.skip(24)
            return .init(id: record, tariff: tariff, priceCents: price, saleDay: sale, counter: counter)
        } catch { return nil }
    }
}

struct RegionalMobibLogInventory: Identifiable {
    let id: String
    let recordsRead: Int
    let nonzeroRecords: Int
}

extension RegionalCardCapture {
    var mobibLogInventory: [RegionalMobibLogInventory] {
        guard hasMobibLayout else { return [] }
        return ["2010", "2011", "2012", "2016", "2017", "2018", "2040"].compactMap { file in
            guard let records = mobibRecords(file) else { return nil }
            return .init(id: file, recordsRead: records.count,
                         nonzeroRecords: records.values.filter { $0.contains(where: { $0 != "0" }) }.count)
        }
    }

    /// Root-relative FIDs are interpreted only in the actual Belgian app.
    /// Explicit zero records are authoritative; older scans never replace them.
    func mobibRecords(_ file: String, includingPrevious: Bool = true) -> [Int: String]? {
        let prefix = "READ PATH APP \(file) / "
        var records: [Int: String] = [:]
        for exchange in exchanges where exchange.statusWord == "9000" && exchange.operation.hasPrefix(prefix) {
            guard (exchange.application ?? selectedApplication).uppercased() == "315449432E494341D05600019101",
                  let token = exchange.operation.dropFirst(prefix.count).split(separator: " ").first,
                  let record = Int(token), (1...254).contains(record) else { continue }
            let value = exchange.response.uppercased()
            if let old = records[record], old != value { return nil }
            records[record] = value
        }
        if records.isEmpty && includingPrevious, let uid = exploration?.cardIdentifier {
            for prior in priorReads.sorted(by: { $0.date > $1.date }) where prior.exploration?.cardIdentifier == uid {
                if let result = prior.mobibRecords(file, includingPrevious: false), !result.isEmpty { return result }
            }
        }
        return records.isEmpty ? nil : records
    }
    var usesEarlierMobibReads: Bool {
        ["2001", "2010", "2017", "2020", "2069"].contains {
            mobibRecords($0, includingPrevious: false) == nil && mobibRecords($0) != nil
        }
    }
    var hasMobibLayout: Bool {
        guard let hex = mobibRecords("2001")?[1], var b = MobibBits(hex) else { return false }
        do { try b.skip(13); return try b.read(24) == 0x056001 } catch { return false }
    }
    var mobibTechnicalExpiryDay: Int? {
        guard hasMobibLayout, let raw = mobibRecords("2001")?[1], var bits = MobibBits(raw) else { return nil }
        do {
            guard try bits.read(6) == 3 else { return nil }
            try bits.skip(36)
            let day = try bits.read(14)
            return (1..<0x3FFF).contains(day) ? day : nil
        } catch { return nil }
    }
    var mobibEvents: [RegionalMobibEvent] {
        guard hasMobibLayout else { return [] }
        var seen = Set<String>()
        return ["2010", "2017"].flatMap { file in
            (mobibRecords(file) ?? [:]).sorted { $0.key < $1.key }.compactMap { record, hex -> RegionalMobibEvent? in
                guard let event = RegionalMobibEvent.decode(hex, file: file, record: record), seen.insert(hex).inserted else { return nil }
                return event
            }
        }.sorted { ($0.header.day, $0.header.minutes) > ($1.header.day, $1.header.minutes) }
    }
    var mobibTitles: [RegionalMobibTitle] {
        guard hasMobibLayout else { return [] }
        let counters = mobibRecords("2069")?[1]
        return (mobibRecords("2020") ?? [:]).sorted { $0.key < $1.key }.compactMap { record, hex in
            var counter: Int?
            if let counters, counters.count >= record * 6 {
                counter = Int(counters.dropFirst((record - 1) * 6).prefix(6), radix: 16)
            }
            return RegionalMobibTitle.decode(hex, record: record, counter: counter)
        }
    }
    var decodedJourneyCount: Int { regionalEvents.count + mobibEvents.count }
}
