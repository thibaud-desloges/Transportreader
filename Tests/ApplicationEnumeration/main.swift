import Foundation
let prefix = "A000000291"
func fci(_ aid: String) -> Data {
    var bytes: [UInt8] = []
    var index = aid.startIndex
    while index < aid.endIndex { let end = aid.index(index, offsetBy: 2); bytes.append(UInt8(aid[index..<end], radix: 16)!); index = end }
    return Data([0x6F, UInt8(bytes.count + 2), 0x84, UInt8(bytes.count)] + bytes)
}
let aid1 = prefix + "000001", aid2 = prefix + "000002"
precondition(RegionalApplicationEnumeration.selectedAID(response: fci(aid1), prefix: prefix) == aid1)
precondition(RegionalApplicationEnumeration.selectedAID(response: fci(aid1), prefix: "A000000404") == nil)
precondition(RegionalApplicationEnumeration.selectedAID(response: Data([0x6F, 100]), prefix: prefix) == nil)
var capture = RegionalCardCapture()
var cursor = RegionalScanPlan.Cursor(applications: [], cardIdentifier: "synthetic")
cursor.applicationPrefixes = [prefix]
precondition(!cursor.finished)
cursor.applicationPrefixIndex = 1
precondition(cursor.finished)
cursor.applications = [aid1]
precondition(!cursor.finished)
cursor.nextApplication()
precondition(cursor.finished)
let restored = try JSONDecoder().decode(RegionalScanPlan.Cursor.self, from: JSONEncoder().encode(cursor))
precondition(restored == cursor)
capture.exploration = cursor
func reply(_ i: Int, aid: String, status: String = "9000") -> RegionalCardCapture.Exchange {
    .init(operation: "SELECT APPLICATION OCCURRENCE \(prefix) / \(i)", response: fci(aid).map { String(format: "%02X", $0) }.joined(), statusWord: status)
}
capture.exchanges = [reply(0, aid: aid1), reply(1, aid: aid2), reply(2, aid: aid2, status: "6A82")]
precondition(capture.applicationFamilyResults[0].ended && capture.applicationFamilyResults[0].applicationCount == 2)
capture.exchanges = [reply(0, aid: aid1), reply(1, aid: aid1)]
precondition(!capture.applicationFamilyResults[0].ended && capture.applicationFamilyResults[0].repeated)
capture.exchanges = [reply(0, aid: aid1, status: "6A86")]
precondition(!capture.applicationFamilyResults[0].ended)
capture.exploration?.knownApplicationIDs = [aid1]
capture.exchanges = [reply(0, aid: aid1, status: "6A82")]
precondition(!capture.applicationFamilyResults[0].ended) // known app: prefix selection unavailable
capture.exploration?.knownApplicationNames = [aid1, aid2]
capture.exchanges = [reply(0, aid: aid1), reply(1, aid: aid1, status: "6A82")]
precondition(!capture.applicationFamilyResults[0].ended && capture.applicationFamilyResults[0].missingKnownNames == 1)
print("FIRST/NEXT: FCI parsing, namespace limits, finite-list evidence, unsupported commands, cycles and checkpoint round-trip passed")
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
for (i, path) in CommandLine.arguments.dropFirst().enumerated() {
    let real = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let coverage = real.enumeratedReadCoverage
    precondition(coverage.count == 29)
    precondition(coverage.filter(\.complete).count == (i == 0 ? 28 : 27))
    precondition(coverage.filter(\.refused).count == (i == 0 ? 1 : 2))
    print("Actual announced files: \(coverage.filter(\.complete).count)/29 fully covered; refusals separated from read gaps")
}
