import Foundation
precondition(RegionalApplicationAccess.permits("A0000004040225092001", declared: ["a0000004040225092001"]))
precondition(!RegionalApplicationAccess.permits("A0000004040225092001", declared: ["A0000004040125092001"]))
precondition(!RegionalApplicationAccess.permits("A0000004040225092001", declared: ["A000000404"]))
let plist = try Data(contentsOf: URL(fileURLWithPath: "metroreader/metroreader/Info.plist"))
let config = try PropertyListSerialization.propertyList(from: plist, format: nil) as! [String: Any]
let declared = config[RegionalApplicationAccess.configurationKey] as! [String]
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let cursor = capture.exploration!
    precondition(cursor.application == 2 && cursor.applications.count == 6)
    precondition(cursor.applications.allSatisfy { RegionalApplicationAccess.permits($0, declared: declared) })
    let restored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(cursor))
    precondition(restored == cursor) // resume stays on the newly authorized third AID
    print("Blocked capture: all six AIDs authorized; exact resume position preserved")
}
print("Application access: all checks passed")
