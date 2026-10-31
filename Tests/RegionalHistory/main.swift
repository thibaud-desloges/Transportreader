import Foundation

let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let url = folder.appendingPathComponent("history.json")
let store = RegionalHistory(url: url)
var capture = RegionalCardCapture()
capture.date = Date(timeIntervalSince1970: 1700000000.123)
capture.exchanges = [.init(operation: "READ test", response: "01", statusWord: "9000")]
capture.exploration = RegionalScanPlan.Cursor(applications: ["test"], cardIdentifier: "card-A")
store.save(capture, enabled: true)
precondition(store.records.isEmpty) // unfinished scan
capture.exploration?.nextApplication()
store.save(capture, enabled: false)
precondition(store.records.isEmpty) // same opt-in as Navigo
store.save(capture, enabled: true)
precondition(store.records.count == 1)
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let reloadedCapture = try decoder.decode(RegionalCardCapture.self, from: Data(capture.json.utf8))
store.save(reloadedCapture, enabled: true)
precondition(store.records.count == 1) // resumptions don't duplicate after date round trip
capture.date = capture.date.addingTimeInterval(3600)
store.save(capture, enabled: true)
precondition(store.records.count == 1) // a new read of the same physical card
precondition(store.records[0].scans?.count == 2)
precondition(store.records[0].date < store.records[0].lastReadDate!)
capture.exploration?.cardIdentifier = "card-B"
store.save(capture, enabled: true)
precondition(store.records.count == 2)
let loaded = RegionalHistory(url: url)
precondition(loaded.records.count == 2)
loaded.delete([loaded.records[0].id])
precondition(loaded.records.count == 1)
loaded.clearAll()
precondition(loaded.records.isEmpty && !FileManager.default.fileExists(atPath: url.path))
try Data("corrupted".utf8).write(to: url)
let damaged = RegionalHistory(url: url)
damaged.save(capture, enabled: true)
precondition(damaged.error != nil)
let preserved = try String(contentsOf: url, encoding: .utf8)
precondition(preserved == "corrupted")
precondition(RegionalStationNames.name(code: 8582, network: 0x250920) == "Marseille–Saint-Charles")
precondition(RegionalStationNames.name(code: 13143, network: 0x250920) == "Toulon")
precondition(RegionalStationNames.name(code: 16008, network: 0x250920) == "Les Arcs–Draguignan")
precondition(RegionalStationNames.name(code: 13143, network: 0) == nil)
print("Regional history: opt-in, completion, persistence, replay, deletion, corrupt-file protection and scoped stations passed")

// Existing timestamp-based duplicates migrate into one card, preserving both
// original reads and the first date, and keeping different UIDs separate.
let migrationURL = folder.appendingPathComponent("legacy.json")
var older = reloadedCapture
older.exploration?.cardIdentifier = "old-card"
var newer = older; newer.date = older.date.addingTimeInterval(120)
let legacy = [RegionalHistoryRecord(id: "old-card:one", date: older.date, capture: older),
              RegionalHistoryRecord(id: "old-card:two", date: newer.date, capture: newer)]
let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
try encoder.encode(legacy).write(to: migrationURL)
let migrated = RegionalHistory(url: migrationURL)
precondition(migrated.records.count == 1 && migrated.records[0].scans?.count == 2)
precondition(migrated.records[0].capture.date == newer.date && migrated.records[0].date == older.date)
precondition(FileManager.default.fileExists(atPath: migrationURL.appendingPathExtension("before-card-grouping.json").path))
precondition(RegionalHistory(url: migrationURL).records.count == 1)
print("Legacy duplicate migration passed; original snapshots and backup retained")
if CommandLine.arguments.count > 1 {
    let realURL = folder.appendingPathComponent("private-fixture.json")
    try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])).write(to: realURL)
    let real = RegionalHistory(url: realURL)
    precondition(real.records.count == 3)
    precondition(Set(real.records.map(\.id)) == ["card:C6B1B0D9", "card:7522843B", "card:07E7EA89"])
    precondition(real.records.first { $0.id == "card:C6B1B0D9" }!.scans!.count == 2)
    precondition(real.records.first { $0.id == "card:7522843B" }!.scans!.count == 2)
    precondition(real.records.first { $0.id == "card:07E7EA89" }!.capture.transportRegion == .lignesAzur)
    precondition(real.records.first { $0.id == "card:C6B1B0D9" }!.date == ISO8601DateFormatter().date(from: "2026-10-19T13:59:09Z")!)
    print("Private five-entry history migrated to three cards; ZOU duplicate pairs grouped and Nice reclassified")
}

// Personalization survives rescans and disk reload; recency uses the latest read.
let personalURL = folder.appendingPathComponent("personal.json")
let personalized = RegionalHistory(url: personalURL)
var first = reloadedCapture
first.exploration?.cardIdentifier = "A"
personalized.save(first, enabled: true)
let firstID = personalized.records[0].id
personalized.personalize(firstID, nickname: "Ma carte", imageName: "ZouCard")
var second = first
second.exploration?.cardIdentifier = "B"
second.date = first.date.addingTimeInterval(100)
personalized.save(second, enabled: true)
precondition(personalized.records[0].capture.exploration?.cardIdentifier == "B")
first.date = first.date.addingTimeInterval(200)
personalized.save(first, enabled: true)
let disk = RegionalHistory(url: personalURL)
precondition(disk.records[0].id == firstID)
precondition(disk.records[0].displayTitle == "Ma carte" && disk.records[0].imageName == "ZouCard")
precondition(disk.records[0].scans?.count == 2)
print("Personalization persistence and latest-read sorting passed")
let passHeader = RegionalContract.decodeCommonHeader(hex: "FE0ACA66ABDCD18A05505A02CE008045B30C1C2E000000140100000000", reference: .init(pointer: 1, structure: 0x20))
precondition(passHeader?.provider == 5 && passHeader?.tariff == 25907 && passHeader?.status == 1)
precondition(RegionalContract.decodeCommonHeader(hex: "FE0A", reference: .init(pointer: 1, structure: 0x20)) == nil)
precondition(RegionalContract.decodeCommonHeader(hex: "FE0ACA66ABDCD18A05505A02CE008045B30C1C2E000000140100000000", reference: .init(pointer: 1, structure: 0x46)) == nil)
print("Partial common title prefix: issuer/tariff, truncation and variant guards passed")
