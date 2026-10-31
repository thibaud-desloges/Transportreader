import Foundation

/// Partial, bounds-checked Intercode decoding. Commercial names and remaining
/// proprietary fields are intentionally left uninterpreted.
struct RegionalContract: Identifiable, Equatable {
    let id: Int
    let provider: Int
    let tariff: Int
    let startDay: Int
    let endDay: Int
    var passengerClass: Int? = nil
    var saleDay: Int? = nil
    var priceCents: Int? = nil
    var structure: Int = 0
    var status: Int? = nil
    var priority: Int? = nil
    var serialNumber: Int? = nil
    var zones: Int? = nil
    var saleDevice: Int? = nil
    var saleAgent: Int? = nil
    var paymentMethod: Int? = nil
    var linkedContract: Int? = nil
    var receiptDelivered: Bool? = nil
    var vehicleCode: Int? = nil
    var decodedBitCount: Int = 0
    var hasUndecodedNonzeroBits = false

    var statusLabel: String {
        switch status {
        case 0: return "Jamais utilisé · code 0"
        case 1: return "Utilisé · code 1"
        case 13: return "Non validable selon le référentiel · code 13"
        default: return status.map { "Statut à interpréter · code \($0)" } ?? "Non renseigné"
        }
    }

    var validity: String { "Du \(Self.dateLabel(startDay)) au \(Self.dateLabel(endDay))" }

    static func dateLabel(_ day: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let epoch = calendar.date(from: DateComponents(year: 1997, month: 1, day: 1))!
        let date = calendar.date(byAdding: .day, value: day, to: epoch)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02d/%02d/%04d", parts.day!, parts.month!, parts.year!)
    }

    private struct BitReader {
        let bits: [UInt8]
        var position = 0
        init?(_ hex: String) {
            guard !hex.isEmpty, hex.count <= 512, hex.count.isMultiple(of: 2),
                  hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
            bits = hex.flatMap { character -> [UInt8] in
                let value = UInt8(String(character), radix: 16)!
                return (0..<4).reversed().map { (value >> $0) & 1 }
            }
        }
        mutating func read(_ width: Int) throws -> Int {
            guard width >= 0, width <= 32, position + width <= bits.count else { throw Invalid.truncated }
            var value = 0
            for bit in bits[position..<position + width] { value = value << 1 | Int(bit) }
            position += width
            return value
        }
    }
    private enum Invalid: Error { case truncated }

    struct Reference: Equatable {
        let pointer: Int
        let structure: Int
        var priority: Int? = nil
    }

    static func references(hex: String) -> [Reference]? {
        guard var reader = BitReader(hex) else { return nil }
        do {
            let count = try reader.read(4)
            var references: [Reference] = []
            var seen = Set<Int>()
            for _ in 0..<count {
                let mask = try reader.read(3)
                if mask & 1 != 0 { _ = try reader.read(24) }
                let tariff = mask & 2 != 0 ? try reader.read(16) : nil
                let pointer = mask & 4 != 0 ? try reader.read(5) : nil
                if let tariff, let pointer, pointer > 0 {
                    guard seen.insert(pointer).inserted else { return nil }
                    references.append(.init(pointer: pointer, structure: (tariff >> 4) & 255, priority: tariff & 15))
                }
            }
            return references
        } catch { return nil }
    }

    static func decode(hex: String, reference: Reference) -> RegionalContract? {
        // Only the common-format variants observed on the tested ZOU! card.
        // The FF extended format has a different bitmap and must not enter here.
        guard [0x20, 0x03].contains(reference.structure), reference.pointer > 0,
              var reader = BitReader(hex) else { return nil }
        do {
            let mask = try reader.read(7)
            guard mask & 0x13 == 0x13 else { return nil } // provider, tariff, validity
            let provider = try reader.read(8)
            let tariff = try reader.read(16)
            let serial = mask & 4 != 0 ? try reader.read(32) : nil
            let passengerClass = mask & 8 != 0 ? try reader.read(8) : nil
            guard try reader.read(2) == 3 else { return nil }
            let start = try reader.read(14)
            let end = try reader.read(14)
            let status = mask & 32 != 0 ? try reader.read(8) : nil
            var saleDay: Int?
            var priceCents: Int?
            var zones: Int?
            var saleDevice: Int?
            var saleAgent: Int?
            var paymentMethod: Int?
            var linked: Int?
            var receipt: Bool?
            var vehicle: Int?
            if mask & 64 != 0 && reference.structure == 0x20 {
                let extra = try reader.read(10)
                let fields = [[16, 16, 16], [16, 16], [16], [14, 16, 8], [11, 16, 1], [6], [14, 6], [8, 5], [4], [5]]
                for (field, widths) in fields.enumerated() where extra & (1 << field) != 0 {
                    for (index, width) in widths.enumerated() {
                        let value = try reader.read(width)
                        if field == 2 { zones = value }
                        if field == 3 && index == 0 { saleDay = value }
                        if field == 3 && index == 1 { saleDevice = value }
                        if field == 3 && index == 2 { saleAgent = value }
                        if field == 4 && index == 0 { paymentMethod = value }
                        if field == 9 { linked = value }
                        if field == 4 && index == 2 { receipt = value != 0 }
                        if field == 8 { vehicle = value }
                        if field == 4 && index == 1 { priceCents = value }
                    }
                }
            }
            guard start > 0, end < 0x3FFF, start <= end else { return nil }
            return .init(id: reference.pointer, provider: provider, tariff: tariff, startDay: start, endDay: end,
                         passengerClass: passengerClass, saleDay: saleDay, priceCents: priceCents,
                         structure: reference.structure, status: status, priority: reference.priority,
                         serialNumber: serial, zones: zones, saleDevice: saleDevice, saleAgent: saleAgent,
                         paymentMethod: paymentMethod, linkedContract: linked, receiptDelivered: receipt, vehicleCode: vehicle, decodedBitCount: reader.position,
                         hasUndecodedNonzeroBits: reader.bits.dropFirst(reader.position).contains(1))
        } catch { return nil }
    }

    /// Only the common prefix of structure 46 observed on the passenger's Nice
    /// card. Its extension is not structure 20: no invented dates, price or balance.
    /// Common Intercode prefix only. A title with an unsupported validity
    /// bitmap still has an independently readable issuer, tariff and serial.
    static func decodeCommonHeader(hex: String, reference: Reference) -> RegionalTitleHeader? {
        guard reference.structure == 0x20, var reader = BitReader(hex) else { return nil }
        do {
            let mask = try reader.read(7)
            guard mask & 7 == 7 else { return nil }
            let provider = try reader.read(8), tariff = try reader.read(16), serial = try reader.read(32)
            let passengerClass = mask & 8 != 0 ? try reader.read(8) : nil
            var start: Int?, end: Int?, sale: Int?
            var zones: Int?, saleDevice: Int?, saleAgent: Int?, payment: Int?, price: Int?
            var storedValue: Int?, debit: Int?
            if mask & 16 != 0 {
                let dates = try reader.read(2)
                if dates & 1 != 0 { start = try reader.read(14) }
                if dates & 2 != 0 { end = try reader.read(14) }
                guard [start, end].compactMap({ $0 }).allSatisfy({ (1..<0x3FFF).contains($0) }) else { return nil }
                if let start, let end, start > end { return nil }
            }
            let status = mask & 32 != 0 ? try reader.read(8) : nil
            if mask & 64 != 0 {
                let extra = try reader.read(10)
                let widths = [[16,16,16], [16,16], [16], [14,16,8], [11,16,1], [6], [14,6], [8,5], [4], [5]]
                for (field, sizes) in widths.enumerated() where extra & (1 << field) != 0 {
                    for (index, width) in sizes.enumerated() {
                        let value = try reader.read(width)
                        if field == 2 { zones = value }
                        if field == 3 && index == 0 { sale = value }
                        if field == 3 && index == 1 { saleDevice = value }
                        if field == 3 && index == 2 { saleAgent = value }
                        if field == 4 && index == 0 { payment = value }
                        if field == 4 && index == 1 { price = value }
                        if field == 7 && index == 0 { storedValue = value }
                        if field == 7 && index == 1 { debit = value }
                    }
                }
            }
            return .init(id: reference.pointer, provider: provider, tariff: tariff,
                         structure: reference.structure, serial: serial, status: status,
                         startDay: start, endDay: end, saleDay: sale,
                         passengerClass: passengerClass, zones: zones, saleDevice: saleDevice,
                         saleAgent: saleAgent, paymentMethod: payment, encodedPrice: price,
                         storedValue: storedValue, debit: debit,
                         decodedBitCount: reader.position,
                         hasUndecodedNonzeroBits: reader.bits.dropFirst(reader.position).contains(1))
        } catch { return nil }
    }

    static func decodeNiceHeader(hex: String, reference: Reference) -> RegionalTitleHeader? {
        guard reference.structure == 0x46, var reader = BitReader(hex) else { return nil }
        do {
            guard try reader.read(7) == 0x67 else { return nil }
            let provider = try reader.read(8)
            let tariff = try reader.read(16)
            let serial = try reader.read(32)
            let status = try reader.read(8)
            guard provider == 25 else { return nil }
            return .init(id: reference.pointer, provider: provider, tariff: tariff,
                         structure: reference.structure, serial: serial, status: status)
        } catch { return nil }
    }
}

struct RegionalTitleHeader: Identifiable {
    let id: Int
    let provider: Int
    let tariff: Int
    let structure: Int
    let serial: Int
    let status: Int?
    var startDay: Int? = nil
    var endDay: Int? = nil
    var saleDay: Int? = nil
    var passengerClass: Int? = nil
    var zones: Int? = nil
    var saleDevice: Int? = nil
    var saleAgent: Int? = nil
    var paymentMethod: Int? = nil
    var encodedPrice: Int? = nil
    var storedValue: Int? = nil
    var debit: Int? = nil
    var decodedBitCount: Int = 0
    var hasUndecodedNonzeroBits = false
}

extension RegionalCardCapture {
    var regionalUninterpretedTitles: [RegionalTitleHeader] {
        guard [.lignesAzur, .passPass].contains(transportRegion),
              let first = ticketingRecords(sfi: 9, path: "20002020"),
              let last = first.keys.max(), last > 0, Set(first.keys) == Set(1...last),
              let second = ticketingRecords(sfi: 6, path: "20002030"),
              let list = ticketingRecords(sfi: 30, path: "20002050")?[1],
              let references = RegionalContract.references(hex: list) else { return [] }
        return references.compactMap { reference in
            guard let hex = reference.pointer <= last ? first[reference.pointer] : second[reference.pointer - last] else { return nil }
            if transportRegion == .passPass {
                guard RegionalContract.decode(hex: hex, reference: reference) == nil else { return nil }
                return RegionalContract.decodeCommonHeader(hex: hex, reference: reference)
            }
            return RegionalContract.decodeNiceHeader(hex: hex, reference: reference)
        }
    }
    /// Join the card's actual contract list to its two record banks. Duplicate
    /// SFI/path reads are collapsed; disagreeing copies are never guessed at.
    var regionalContracts: [RegionalContract] {
        guard transportRegion != .mobib else { return [] }
        guard let first = ticketingRecords(sfi: 9, path: "20002020"),
              let last = first.keys.max(), last > 0,
              Set(first.keys) == Set(1...last),
              let second = ticketingRecords(sfi: 6, path: "20002030"),
              let list = ticketingRecords(sfi: 30, path: "20002050")?[1],
              let references = RegionalContract.references(hex: list) else { return [] }
        return references.compactMap { reference in
            let hex = reference.pointer <= last ? first[reference.pointer] : second[reference.pointer - last]
            guard let hex else { return nil }
            return RegionalContract.decode(hex: hex, reference: reference)
        }
    }
}
