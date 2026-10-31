import Foundation

// Integration check on two private local reports; no personal capture is embedded.
precondition(CommandLine.arguments.count == 3, "Pass current and previous card captures")
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
func load(_ path: String) throws -> RegionalCardCapture {
    try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}
let current = try load(CommandLine.arguments[1])
let previous = try load(CommandLine.arguments[2])
precondition(current.regionalEvents.count == 3)
precondition(current.regionalEvents.allSatisfy {
    $0.device == nil && $0.undecodedTailHex == nil && !$0.hasUndecodedNonzeroBits
})
precondition(previous.regionalEvents.count == 6)
precondition(previous.regionalEvents.allSatisfy {
    $0.mode == 5 && $0.provider == 2 && $0.contract == 1 &&
    $0.device == $0.location && $0.paddingBitCount == 64 &&
    $0.hasUndecodedNonzeroBits && $0.undecodedTailHex == "1E02020000000000"
})
precondition(Set(previous.regionalEvents.compactMap(\.location)) == [8582, 13143, 16008])
precondition(current.regionalContracts.count == 2)
precondition(previous.regionalContracts.count == 1)
precondition(previous.regionalContracts[0].structure == 0x20)
if previous.exchanges.contains(where: { $0.operation == "READ PATH APP 2040 / 1" && $0.statusWord == "9000" }) {
    precondition(previous.regionalSpecialEvents.count == 1)
    let special = previous.regionalSpecialEvents[0]
    precondition(!special.hasRecordedCode && special.result == 34 && special.provider == 2)
    precondition(special.location == 13143 && special.device == 13143 && special.contract == 1)
    precondition(special.header.label == "30/04/2026 à 18:34")
    precondition(!special.hasUndecodedNonzeroBits && special.paddingBitCount == 126)
    precondition(current.regionalSpecialEvents.isEmpty)
    let raw = previous.exchanges.first { $0.operation == "READ PATH APP 2040 / 1" && $0.statusWord == "9000" }!.response
    precondition(RegionalEvent.decode(hex: raw, record: 1) == nil, "Special entry without EventCode must not enter normal journey log")
    precondition(RegionalEvent.decode(hex: String(raw.prefix(20)), record: 1, requiresEventCode: false) == nil)
    print("Separate special event: date, result 34, title 1, no mode inferred")
}
for c in previous.regionalContracts {
    print("Previous title: slot \(c.id), provider \(c.provider), tariff \(c.tariff), status \(c.status ?? -1), \(c.validity), price \(c.priceCents ?? -1), sale \(c.saleDay ?? -1)")
}
print("Two-card comparison passed: six older rail events, shared unknown suffix, one older title; current card unchanged")
