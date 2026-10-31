import Foundation

let eventHex = "0E7597B404201006616E6006CF0F1D3AAB8000068000004EB2F682DCC000000000000000000000000000000000000000"
let titleHex = "118A91500661B43B80CE14834802C9D5800200FF0000000000788A623B00000000000000000000000000000000000000"
let event = RegionalMobibEvent.decode(eventHex, file: "2017", record: 1)!
precondition(event.header.day == 10073 && event.header.minutes == 986)
precondition(event.header.label == "31/07/2024 à 16:26")
precondition(event.mode == 15 && event.route == 54 && event.busLocation == 2931 && event.location == 7738)
precondition(event.sequence == 13 && event.firstStamp == event.header)
let title = RegionalMobibTitle.decode(titleHex, record: 1, counter: 4)!
precondition(title.tariff == 0x2803 && title.name == "JUMP 10 voyages")
precondition(title.priceCents == 1680 && title.remainingJourneys == 4 && title.saleDay == 10070)
precondition(RegionalMobibTitle.decode(titleHex, record: 1, counter: nil)?.remainingJourneys == nil)
for hex in ["", "not hex", String(eventHex.dropLast(2)), String(repeating: "0", count: 96), "FE" + eventHex.dropFirst(2)] {
    precondition(RegionalMobibEvent.decode(hex, file: "2017", record: 1) == nil)
}
precondition(RegionalMobibTitle.decode("FE" + titleHex.dropFirst(2), record: 1, counter: 4) == nil)

var capture = RegionalCardCapture()
capture.selectedApplication = "315449432E494341D05600019101"
capture.exploration = .init(applications: [capture.selectedApplication], cardIdentifier: "synthetic")
func read(_ file: String, _ hex: String) -> RegionalCardCapture.Exchange {
    .init(operation: "READ PATH APP \(file) / 1", response: hex, statusWord: "9000", application: "315449432E494341D05600019101")
}
capture.exchanges = [read("2001", "0C382B0008AE772A4000000018E594C080486621E6604000000000000000000000000000000000000000000000000000"), read("2010", String(repeating: "0", count: 96)), read("2017", eventHex), read("2020", titleHex), read("2069", "000004" + String(repeating: "0", count: 66))]
precondition(capture.hasMobibLayout && capture.mobibEvents.count == 1 && capture.mobibTitles.count == 1)
precondition(capture.mobibTitles[0].remainingJourneys == 4)
var supplement = capture
supplement.exchanges = [capture.exchanges[0]]
supplement.priorReads = [capture]
precondition(supplement.mobibEvents.count == 1)
supplement.exchanges.append(read("2017", String(repeating: "0", count: 96)))
precondition(supplement.mobibEvents.isEmpty) // explicit empty file overrides history
var wrongCard = capture; wrongCard.exploration?.cardIdentifier = "other"
supplement.exchanges = [capture.exchanges[0]]; supplement.priorReads = [wrongCard]
precondition(supplement.mobibEvents.isEmpty)
var conflict = capture
conflict.exchanges.append(read("2017", String(repeating: "0", count: 96)))
precondition(conflict.mobibEvents.isEmpty)
var foreign = capture
foreign.exchanges = capture.exchanges.map { e in var result = e; result.application = "334D54522E494341"; return result }
precondition(!foreign.hasMobibLayout && foreign.mobibEvents.isEmpty)

let list = RegionalContract.Reference(pointer: 1, structure: 0x20)
let pass = RegionalContract.decodeCommonHeader(hex: "FE0ACA66ABDCD18A05505A02CE008045B30C1C2E000000140100000000", reference: list)!
precondition(pass.provider == 5 && pass.tariff == 25907 && pass.startDay == nil)
precondition(pass.endDay == 10285 && pass.saleDay == 8921 && pass.status == 1)
print("MOBIB event/title decode, scope, variants, truncation, counter absence, history fallback and zero/conflict protection passed; Pass Pass end-only validity passed")

if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let actual = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    precondition(actual.mobibEvents.count == 1 && actual.mobibTitles.count == 1)
    precondition(actual.mobibEvents[0].route == 54 && actual.mobibEvents[0].header.label == "31/07/2024 à 16:26")
    precondition(actual.mobibTitles[0].remainingJourneys == 4)
    precondition(actual.regionalEvents.isEmpty && actual.regionalContracts.isEmpty)
    print("Private real MOBIB capture replay passed")
}
var quick = RegionalScanPlan.Cursor(applications: ["315449432E494341D05600019101"], cardIdentifier: "synthetic")
quick.quick = true; quick.region = .mobib
precondition(quick.locations.count == 14)
precondition(["PATH APP 2017", "PATH APP 2069"].allSatisfy { label in quick.locations.contains { $0.label == label } })
if CommandLine.arguments.count > 2 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    var actual = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
    actual.declaredRegion = .passPass
    precondition(actual.regionalUninterpretedTitles.count == 1)
    precondition(actual.regionalUninterpretedTitles[0].endDay == 10285)
    precondition(actual.regionalUninterpretedTitles[0].saleDay == 8921)
    precondition(actual.regionalEvents.count == 6)
    precondition(actual.eventProviderName(23) == "Ilévia")
    precondition(actual.regionalEvents.compactMap { actual.eventRouteName($0) }.sorted() == ["Métro 1", "Métro 1", "Métro 2", "Métro 2"])
    print("Private real Pass Pass capture replay and MOBIB quick-plan targets passed")
}

precondition(event.placeName == "Trinité")
if CommandLine.arguments.count > 1 {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    let actual = try d.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    precondition(actual.mobibLogInventory.reduce(0) { $0 + $1.recordsRead } == 43)
    precondition(actual.mobibLogInventory.reduce(0) { $0 + $1.nonzeroRecords } == 1)
}
if CommandLine.arguments.count > 3 {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    var actual = try d.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
    actual.declaredRegion = .oura
    let profile = actual.regionalEnvironment!
    precondition(profile.network == 0x250502 && profile.issuer == 199 && profile.versionLabel == "Intercode 2.1")
    precondition(profile.expiryLabel == "05/01/2028" && profile.personalizationLabel == "Nominative")
    precondition(profile.commercialCode == 7 && profile.birthDate != nil)
    precondition(actual.regionalEvents.isEmpty && actual.regionalContracts.isEmpty)
    print("Unused Oùra: support expiry, personalization, commercial code and private holder field decoded without inventing journeys")
}
// Every supported region gets the same broad, resumable public-read plan.
for region in TransportRegion.allCases {
    var cursor = RegionalScanPlan.Cursor(applications: ["test", "next"], cardIdentifier: "synthetic")
    cursor.region = region
    cursor.supplementary = true
    cursor.wideDirectories = true
    precondition(cursor.contexts.count == 256 && Set(cursor.contexts).count == 256)
    precondition(cursor.contexts.contains([0x20, 0]) && cursor.contexts.contains([0x80, 0]))
    precondition(cursor.locations.filter { $0.directory == nil && $0.sfi != nil }.count == 30)
    precondition(cursor.locations.contains { $0.path == [0x2F, 0] })
    precondition(cursor.locations.contains { $0.path == [0x20, 0x17] && $0.relativeToApplication == true })
    let encoded = try JSONEncoder().encode(cursor)
    let restored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: encoded)
    precondition(restored == cursor)
    cursor.enumerationCompleted = true
    cursor.nextApplication()
    precondition(cursor.enumerationCompleted == nil && cursor.wideDirectories == true)
}
print("Universal research: all six regions, 256 distinct directory contexts, root SFIs, ISO directory, native paths and resumable cursor passed")
