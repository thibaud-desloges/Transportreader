import Foundation

let locations = RegionalScanPlan.locations
let directories = RegionalScanPlan.directoryContexts(for: "334D54522E494341")
precondition(directories.count == 256)
precondition(Set(directories.map { $0.map(String.init).joined(separator: ",") }).count == 256)
precondition(directories.first == [])
for high in 1...255 { precondition(directories.contains([UInt8(high), 0])) }
precondition(RegionalScanPlan.directoryContexts(for: "A0000004040125092001").count == 6)
let sfis = locations.compactMap(\.sfi)
precondition(Set(sfis) == Set(1...30))
precondition(Set(locations.map(\.label)).count == locations.count)
precondition(locations.filter { $0.path != nil }.allSatisfy { [2, 4].contains($0.path!.count) })

var cursor = RegionalScanPlan.Cursor(applications: ["FIRST", "SECOND"], cardIdentifier: "test-only")
cursor.location = 12
cursor.record = 6
cursor.binary = true
cursor.binaryOffset = 512
cursor.directoryIndex = 137
// A restart must preserve the exact interrupted position and card binding.
let restored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(cursor))
precondition(cursor == restored)
cursor.nextLocation()
precondition(cursor.location == 13 && cursor.record == 1 && !cursor.binary && cursor.binaryOffset == 0)
cursor.location = locations.count - 1
cursor.nextLocation()
precondition(cursor.application == 1 && cursor.location == 0 && !cursor.finished)
cursor.location = locations.count - 1
cursor.nextLocation()
precondition(cursor.finished)

var full = RegionalScanPlan.Cursor(applications: ["FIRST", "SECOND"], cardIdentifier: "test-only")
var visited = Set<String>()
while !full.finished {
    precondition(visited.insert("\(full.application)-\(full.location)").inserted)
    full.nextLocation()
}
precondition(visited.count == 2 * locations.count)
print("RegionalScanPlan: full traversal and interruption/resume checks passed (\(locations.count) locations/application)")

var quick = RegionalScanPlan.Cursor(applications: ["ZOU"], cardIdentifier: "test")
quick.quick = true; quick.directoryRead = true
precondition(quick.locations.count == 6)
precondition(quick.locations.last?.path == [0x20, 0, 0x20, 0x40])
precondition(quick.locations.allSatisfy { $0.sfi == nil && $0.path?.prefix(2) == [0x20, 0] })
let quickRestored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(quick))
precondition(quickRestored == quick)
for _ in 0..<6 { quick.nextLocation() }
precondition(quick.finished)
print("Quick scan: six explicit ticketing files including special events, resume and traversal passed")

// Inventory resumes retain selection progress and queued unknown files.
var inventory = RegionalScanPlan.Cursor(applications: ["FIRST", "SECOND"], cardIdentifier: "test")
inventory.enumeration = true
precondition(inventory.locations.isEmpty)
inventory.enumerationSeen = ["descriptor-1", "descriptor-2"]
inventory.additionalLocations = [.init(sfi: nil, path: [0x20, 0x61], relativeToApplication: true)]
let resumedInventory = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(inventory))
precondition(resumedInventory == inventory)
precondition(resumedInventory.locations.count == 1)
inventory.nextLocation()
precondition(inventory.application == 1 && inventory.enumeration == true)
precondition(inventory.enumerationSeen == nil && inventory.locations.isEmpty)
print("Direct inventory: empty plan, checkpoint, queued file and application reset passed")

var support = RegionalScanPlan.Cursor(applications: ["ZOU"], cardIdentifier: "test")
support.supportOnly = true
precondition(support.locations.isEmpty && !support.finished)
let supportResume = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(support))
precondition(supportResume.supportOnly == true && supportResume.cardIdentifier == "test")
support.nextApplication()
precondition(support.finished)
print("Support metadata mode: preserved binding, no read locations, resume and completion passed")
