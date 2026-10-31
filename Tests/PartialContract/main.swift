import Foundation
// Real structure-20 wire shape, independently verified bit offsets. No UID or holder data.
let wire = "FE0ACA660000000205505A02CE008045B30C1C2E000000140100000000"
let ref = RegionalContract.Reference(pointer: 1, structure: 0x20)
let title = RegionalContract.decodeCommonHeader(hex: wire, reference: ref)!
precondition(title.tariff == 25907 && title.provider == 5)
precondition(title.startDay == nil && title.endDay == 10285 && title.saleDay == 8921)
precondition(title.saleDevice == 34318 && title.saleAgent == 23)
precondition(title.passengerClass == 2 && title.zones == 256)
precondition(title.encodedPrice == 0 && title.paymentMethod == 0)
precondition(title.storedValue == 160 && title.debit == 1)
precondition(title.decodedBitCount == 204 && !title.hasUndecodedNonzeroBits)
precondition(RegionalContract.decodeCommonHeader(hex: String(wire.prefix(40)), reference: ref) == nil)
precondition(RegionalContract.decodeCommonHeader(hex: wire, reference: .init(pointer: 1, structure: 0x46)) == nil)
let unknownTail = String(wire.dropLast()) + "1"
precondition(RegionalContract.decodeCommonHeader(hex: unknownTail, reference: ref)!.hasUndecodedNonzeroBits)
print("Pass Pass: optional dates, sale terminal, value parameters, truncation and nonzero tail passed")

let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
if let path = CommandLine.arguments.dropFirst().first {
    var capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    capture.declaredRegion = .passPass
    precondition(capture.priorReads.isEmpty)
    precondition(capture.regionalEvents.count == 6)
    precondition(capture.regionalUninterpretedTitles.first?.saleDevice == 34318)
    // A newer, explicit empty record must never resurrect an old title.
    var zero = capture
    zero.exchanges = capture.exchanges.filter { $0.operation == "READ SFI 09 / 1" }.map {
        .init(operation: $0.operation, response: String(repeating: "0", count: $0.response.count), statusWord: "9000", application: $0.application)
    }
    precondition(!zero.exchanges.isEmpty)
    zero.priorReads = [capture]
    precondition(zero.ticketingRecords(sfi: 9, path: "20002020")?[1]?.allSatisfy { $0 == "0" } == true)
    print("Newest padded Pass Pass AID: 6 events and sale fields read without history fallback; zeros retained")
}
