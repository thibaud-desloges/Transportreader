import Foundation
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let history = try decoder.decode([RegionalHistoryRecord].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let nice = history.first { $0.capture.declaredRegion == .lignesAzur }!
precondition(nice.capture.regionalEvents.count == 1)
precondition(nice.capture.regionalUninterpretedTitles.map(\.tariff) == [191, 99])
precondition(nice.capture.regionalAMC?.encodedDate == "25/10/2024")
let oura = history.first { $0.capture.declaredRegion == .oura }!
let pass = history.first { $0.capture.declaredRegion == .passPass }!
precondition(oura.capture.regionalAMC?.encodedDate == "03/09/2021")
precondition(pass.capture.regionalAMC?.encodedDate == "30/12/2019")
precondition([nice, oura, pass].allSatisfy { $0.capture.regionalAMC?.sectors.count == 35 })
let mobib = history.first { $0.capture.declaredRegion == .mobib }!.capture
let headers = mobib.exchanges.filter { $0.application == mobib.nfcMetadata?.initialSelectedAID && $0.operation.hasPrefix("ENUMERATE EF ") && $0.statusWord == "9000" }
let ids = headers.compactMap { RegionalFileHeader.logicalIdentifier($0.response, legacy: false) }
precondition(ids.count == 19 && Set(ids).count == 19 && ids.first == 0x2001 && ids.contains(0x2010))
// Latest complement without ticketing READs preserves previous known data, but
// an explicitly reread all-zero bank must supersede older entries.
var empty = nice.capture; empty.exchanges.removeAll { $0.operation.hasPrefix("READ ") }
empty.priorReads = [nice.capture]
precondition(empty.regionalEvents.count == 1 && empty.regionalUninterpretedTitles.count == 2 && empty.usesEarlierTicketingReads)
let foreignUID = oura.capture
empty.priorReads = [foreignUID]
precondition(empty.regionalEvents.isEmpty)
empty.priorReads = [nice.capture]
empty.exchanges.append(.init(operation: "READ PATH 20002010 / 1", response: String(repeating: "00", count: 29), statusWord: "9000", application: "334D54522E494341"))
precondition(empty.regionalEvents.isEmpty)
let restored = try decoder.decode(RegionalCardCapture.self, from: Data(empty.json.utf8))
precondition(restored.priorReads.isEmpty) // original snapshots stay unmixed on disk
print("Actual complements: Nice titles and tram restored via scoped SFI; three AMC profiles; 19 distinct MOBIB FIDs; fallback retains same-card unread files without resurrecting explicitly zeroed events")
