import Foundation
func bytes(_ hex: String) -> Data {
    var result = Data(); var index = hex.startIndex
    while index < hex.endIndex {
        let end = hex.index(index, offsetBy: 2)
        result.append(UInt8(hex[index..<end], radix: 16)!); index = end
    }
    return result
}
let aid = "A0000004040125092001"
precondition(RegionalApplicationDirectory.identifiers(bytes("D00C4F0A" + aid)) == [aid])
precondition(RegionalApplicationDirectory.identifiers(bytes("610C4F0A" + aid + "0000")) == [aid])
precondition(RegionalApplicationDirectory.identifiers(bytes("6F0C840A" + aid)) == [aid])
precondition(RegionalApplicationDirectory.identifiers(bytes("D0184F0A" + aid + "4F0A" + aid)) == [aid])
precondition(RegionalApplicationDirectory.identifiers(bytes("530C4F0A" + aid)) == []) // primitive data isn't recursively scanned
for bad in ["D00D4F0A" + aid, "4F01FF", "D080", "D082FFFF", "610C4F0A", "1F80"] {
    precondition(RegionalApplicationDirectory.identifiers(bytes(bad)) == nil)
}
var cursor = RegionalScanPlan.Cursor(applications: ["334D54522E494341"], cardIdentifier: "test")
cursor.supplementary = true; cursor.metadataIndex = 2
precondition(cursor.contexts.count == 6)
precondition(cursor.locations.count == 181)
let scoped = cursor.locations.filter { $0.directory != nil }
precondition(scoped.count == 150 && scoped.allSatisfy { $0.directory?.count == 2 })
precondition(Set(scoped.map(\.label)).count == 150)
let restored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(cursor))
precondition(restored == cursor)
while !cursor.finished { cursor.nextLocation() }
precondition(cursor.metadataIndex == nil)
// Compatibility with older saved cursor layouts.
let old = Data(#"{"applications":["old"],"cardIdentifier":"x","application":0,"location":0,"record":1,"binaryOffset":0,"binary":false,"limitedFiles":[]}"#.utf8)
let legacy = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: old)
precondition(legacy.locations == RegionalScanPlan.locations)
print("Application directory: malformed TLV, linked AIDs, scoped SFI and saved-cursor checks passed")
