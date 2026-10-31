import Foundation

func encode(_ values: [(Int, Int)]) -> String {
    var bits = values.map { value, width in
        let b = String(value, radix: 2)
        return String(repeating: "0", count: width - b.count) + b
    }.joined()
    bits += String(repeating: "0", count: (8 - bits.count % 8) % 8)
    var result = ""
    while !bits.isEmpty {
        result += String(format: "%02X", Int(bits.prefix(8), radix: 2)!)
        bits.removeFirst(8)
    }
    return result
}
let bitmap = (1 << 2) | (1 << 4) | (1 << 8) | (1 << 10) | (1 << 11) | (1 << 25)
let bus = encode([(10000, 14), (720, 11), (bitmap, 28), (0x23, 8), (29, 8), (42, 16), (1234, 16), (59, 16), (6, 5)])
let event = RegionalEvent.decode(hex: bus, record: 1)!
precondition(event.mode == 2 && event.transition == 3 && event.route == 59 && event.location == 42 && event.contract == 6 && event.device == 1234)
precondition(event.modeLabel == "Car / bus interurbain")
for invalid in ["", "GG", "00000000", String(bus.dropLast(6))] {
    precondition(RegionalEvent.decode(hex: invalid, record: 1) == nil)
}

// One public file descriptor: LID 2020, SFI 09, linear, 29 bytes, four records.
let directory = Data([0xC0, 8, 0xC1, 6, 0x20, 0x20, 9, 2, 29, 4])
precondition(RegionalFileDirectory.fileIDs(directory) == [0x2020])
precondition(RegionalFileDirectory.fileIDs(Data(directory.dropLast())) == nil)
precondition(RegionalFileDirectory.fileIDs(Data([0xC0, 0])) == [])
precondition(RegionalFileDirectory.fileIDs(Data([0xC0, 0x80])) == nil)
precondition(RegionalFileDirectory.fileIDs(Data([0xC0, 16] + Array(directory.dropFirst(2)) + Array(directory.dropFirst(2)))) == nil)

var cursor = RegionalScanPlan.Cursor(applications: ["A", "B"], cardIdentifier: "test")
cursor.additionalLocations = [.init(sfi: nil, path: [0x12, 0x34], relativeToApplication: true)]
cursor.directoryRead = true
cursor.location = RegionalScanPlan.locations.count - 1
cursor.nextLocation()
precondition(cursor.application == 0 && cursor.location == RegionalScanPlan.locations.count)
let restored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(cursor))
precondition(restored == cursor)
cursor.nextLocation()
precondition(cursor.application == 1 && cursor.additionalLocations == nil && cursor.directoryRead == nil)

if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let events = report.regionalEvents
    precondition(events.count == 3)
    precondition(events.allSatisfy { $0.mode == 5 && $0.transition == 1 && $0.provider == 2 && $0.contract == 5 && $0.route == nil })
    precondition(events.allSatisfy { $0.device == nil && $0.gate == nil })
    precondition(events.map(\.location) == [16008, 13143, 13143])
    precondition(report.regionalPlace(for: events[0]) == "Les Arcs–Draguignan")
    precondition(report.regionalPlace(for: events[1]) == "Toulon")
    var otherNetwork = report
    otherNetwork.exchanges.removeAll { $0.operation.hasPrefix("READ SFI 07 /") || $0.operation.hasPrefix("READ PATH 20002001 /") || $0.operation.hasPrefix("READ PATH APP 2001 /") }
    precondition(otherNetwork.regionalPlace(for: events[0]) == nil)
    precondition(report.regionalContracts.count == 2)
    precondition(report.regionalContracts[0].priceCents == 9000)
    precondition(report.regionalEvents.allSatisfy { $0.firstStamp == $0.header && !$0.hasUndecodedNonzeroBits && $0.paddingBitCount == 112 })
    print("Real report: three rail entries, contract 5, no route field; location references scoped to network")
}
print("RegionalEvent and file discovery: all checks passed")
