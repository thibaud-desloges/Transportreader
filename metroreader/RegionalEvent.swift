import Foundation

/// Intercode event layout, without any Île-de-France-specific reinterpretation.
struct RegionalEvent: Identifiable, Equatable {
    let id: Int
    let header: RegionalEventHeader
    let code: Int
    let provider: Int?
    let location: Int?
    let route: Int?
    let contract: Int?
    var device: Int? = nil
    var gate: Int? = nil
    var notOKCounter: Int? = nil
    var result: Int? = nil
    var serialNumber: Int? = nil
    var destination: Int? = nil
    var journeyRun: Int? = nil
    var vehicle: Int? = nil
    var amount: Int? = nil
    var monetaryUnit: Int? = nil
    var firstStamp: RegionalEventHeader? = nil
    var simulation: Int? = nil
    var journeyPart: Int? = nil
    var direction: Int? = nil
    var paddingBitCount = 0
    var hasUndecodedNonzeroBits = false
    /// Exact unparsed suffix, only when nibble aligned and nonzero. It is not
    /// silently treated as padding or assigned a transport-specific meaning.
    var undecodedTailHex: String? = nil
    var hasRecordedCode = true
    var mode: Int { code >> 4 }
    var transition: Int { code & 15 }
    var modeLabel: String {
        switch mode {
        case 0: return "Mode non renseigné"
        case 1: return "Bus urbain"
        case 2: return "Car / bus interurbain"
        case 3: return "Métro"
        case 4: return "Tramway"
        case 5: return "Train"
        case 8: return "Parking"
        case 11: return "Consigne à vélo"
        case 14: return "Voiture en libre-service"
        default: return "Mode réservé (\(mode))"
        }
    }
    var transitionLabel: String {
        switch transition {
        case 1: return "Entrée"
        case 2: return "Sortie"
        case 3: return "Validation"
        case 4: return "Contrôle"
        case 6: return "Entrée en correspondance"
        case 7: return "Sortie en correspondance"
        default: return "Événement \(transition)"
        }
    }
    var symbol: String {
        switch mode {
        case 1, 2: return "bus"
        case 3, 4, 5: return "tram"
        default: return "wave.3.forward"
        }
    }

    static func decode(hex: String, record: Int, requiresEventCode: Bool = true) -> RegionalEvent? {
        guard record > 0, let header = RegionalEventHeader(hex: hex) else { return nil }
        let bits = hex.flatMap { character -> [UInt8] in
            let value = UInt8(String(character), radix: 16)!
            return (0..<4).reversed().map { (value >> $0) & 1 }
        }
        var offset = 25
        func read(_ width: Int) -> Int? {
            guard width <= 32, offset + width <= bits.count else { return nil }
            var value = 0
            for bit in bits[offset..<offset + width] { value = value << 1 | Int(bit) }
            offset += width
            return value
        }
        guard let bitmap = read(28) else { return nil }
        let widths = [8, 24, 8, 8, 8, 8, 24, 16, 16, 8, 16, 16, 8, 16, 16, 8, 5, 240, 16, 8, 16, 16, 16, 16, 16, 5, 16]
        var values: [Int: Int] = [:]
        for (field, width) in widths.enumerated() where bitmap & (1 << field) != 0 {
            if width > 32 {
                guard offset + width <= bits.count else { return nil }
                offset += width
            } else {
                guard let value = read(width) else { return nil }
                values[field] = value
            }
        }
        var extras: [Int: Int] = [:]
        if bitmap & (1 << 27) != 0 {
            guard let extra = read(5) else { return nil }
            for (field, width) in [14, 11, 1, 2, 2].enumerated() where extra & (1 << field) != 0 {
                guard let value = read(width) else { return nil }
                extras[field] = value
            }
        }
        guard values[2] != nil || !requiresEventCode else { return nil }
        let code = values[2] ?? 0
        let firstStamp = extras[0].flatMap { day in extras[1].flatMap { RegionalEventHeader(day: day, minutes: $0) } }
        let remainder = bits.dropFirst(offset)
        let hasRemainder = remainder.contains(1)
        var tail: String? = nil
        if hasRemainder && offset.isMultiple(of: 4) {
            tail = String(hex.dropFirst(offset / 4)).uppercased()
        }
        return .init(id: record, header: header, code: code, provider: values[4],
                     location: values[8], route: values[11], contract: values[25],
                     device: values[10], gate: values[9], notOKCounter: values[5], result: values[3], serialNumber: values[6],
                     destination: values[7], journeyRun: values[13], vehicle: values[14], amount: values[23], monetaryUnit: values[24],
                     firstStamp: firstStamp, simulation: extras[2], journeyPart: extras[3], direction: extras[4],
                     paddingBitCount: bits.count - offset, hasUndecodedNonzeroBits: hasRemainder,
                     undecodedTailHex: tail, hasRecordedCode: values[2] != nil)
    }
}

extension RegionalCardCapture {
    var regionalEvents: [RegionalEvent] {
        guard transportRegion != .mobib else { return [] }
        guard let records = ticketingRecords(sfi: 8, path: "20002010") else { return [] }
        return records.keys.sorted().compactMap { record in
            RegionalEvent.decode(hex: records[record]!, record: record)
        }
    }

    /// The separate special-event file can omit EventCode. Such entries must
    /// not be invented as bus/train validations or merged into the journey log.
    var regionalSpecialEvents: [RegionalEvent] {
        guard transportRegion != .mobib else { return [] }
        guard let records = ticketingRecords(sfi: 29, path: "20002040") else { return [] }
        return records.keys.sorted().compactMap { record in
            RegionalEvent.decode(hex: records[record]!, record: record, requiresEventCode: false)
        }
    }

    /// Station associations confirmed by the passenger, not a UIC transformation.
    /// Kept in the regional dictionary rather than editable local annotations.
    /// They are scoped by issuer network, service provider and transport mode.
    func regionalPlace(for event: RegionalEvent) -> String? {
        if transportRegion == .passPass, ticketingNetworkID == 0x250000,
           event.provider == 23, event.mode == 3, event.location == 4850 {
            return "Gare Lille-Flandres"
        }
        guard event.provider == 2, event.mode == 5, ticketingNetworkID == 0x250920 else { return nil }
        guard let code = event.location else { return nil }
        return RegionalStationNames.name(code: code, network: ticketingNetworkID)
    }

}
