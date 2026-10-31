import Foundation

/// Experimental concordance, not a confirmed schema for the structure-03 data.
/// The passenger declared Marseille–Saint-Charles → Toulon as the preferred trip.
/// Keep this separate from decoded contract fields and recorded validations.
struct RegionalPreferredJourneyHint: Equatable {
    let contractID: Int
    let originCandidate: Int
    let destinationCandidate: Int
    let saleDayCandidate: Int
    let saleDeviceCandidate: Int
    var declaredJourney: String { "Marseille–Saint-Charles → Toulon" }
    var declaredLine: String { "TER Marseille–Toulon–Nice · ZOU! / Transdev" }
}

extension RegionalCardCapture {
    var regionalPreferredJourneyHint: RegionalPreferredJourneyHint? {
        guard ticketingNetworkID == 0x250920,
              let right = regionalContracts.first(where: { $0.id == 6 }),
              right.structure == 3, right.provider == 29, right.tariff == 12200, right.status == 13,
              let sold = regionalContracts.first(where: { $0.id == 5 }),
              let hex = ticketingRecords(sfi: 6, path: "20002030")?[2],
              hex.count == 58, hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }) else { return nil }
        let bits = hex.flatMap { character -> [UInt8] in
            let value = UInt8(String(character), radix: 16)!
            return (0..<4).reversed().map { (value >> $0) & 1 }
        }
        func read(_ offset: Int, _ width: Int) -> Int {
            bits[offset..<offset+width].reduce(0) { $0 << 1 | Int($1) }
        }
        let origin = read(69,16), destination = read(85,16), sale = read(101,14), device = read(115,16)
        guard origin == 8582, destination == 13143,
              sale == sold.saleDay, device == sold.saleDevice else { return nil }
        return .init(contractID: right.id, originCandidate: origin, destinationCandidate: destination,
                     saleDayCandidate: sale, saleDeviceCandidate: device)
    }
}
