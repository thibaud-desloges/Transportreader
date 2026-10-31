import Foundation

precondition(CommandLine.arguments.count == 2)
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let records = try decoder.decode([RegionalHistoryRecord].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let recent = records.filter { $0.date >= ISO8601DateFormatter().date(from: "2026-10-19T15:11:00Z")! }.sorted { $0.date < $1.date }
precondition(recent.count == 3)
let regions: [TransportRegion] = [.oura, .passPass, .mobib]
let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "metroreader/metroreader/Info.plist")), format: nil) as! [String: Any]
let permitted = info[RegionalApplicationAccess.configurationKey] as! [String]
for (record, region) in zip(recent, regions) {
    var capture = record.capture
    capture.declaredRegion = region // the passenger's explicit classification
    precondition(capture.transportRegion == region)
    precondition(!capture.hasFileRead && capture.regionalEvents.isEmpty && capture.regionalContracts.isEmpty)
    let aid = capture.nfcMetadata!.initialSelectedAID
    let apps = RegionalScanPlan.quickApplications(region: region, initialAID: aid)
    precondition(apps.first == aid.uppercased())
    precondition(apps.allSatisfy { RegionalApplicationAccess.permits($0, declared: permitted) })
    var cursor = RegionalScanPlan.Cursor(applications: apps, cardIdentifier: "test")
    cursor.quick = true; cursor.region = region
    precondition(cursor.locations.count == (region == .mobib ? 14 : 6))
    let restored = try decoder.decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(cursor))
    precondition(restored == cursor)
    let inventory = RegionalScanPlan.inventoryApplications(initialAID: aid)
    precondition(inventory.contains(aid) && Set(inventory).count == inventory.count)
    precondition(inventory.allSatisfy { RegionalApplicationAccess.permits($0, declared: permitted) })
}
precondition(TransportRegion.allCases.count == 6)
print("Three passenger-identified cards classified without invented content; native AIDs allowed; quick and complementary plans include actual applications; cursor round-trip passed")
