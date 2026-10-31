import Foundation
var bytes = [UInt8](repeating: 0, count: 500)
let header: [UInt8] = [0xE0, 2, 1, 0x25, 0x0E, 0, 0x20, 0x25, 8, 6, 0x1A, 1, 35]
bytes.replaceSubrange(0..<13, with: header)
for i in 0..<35 {
    let start = 13 + i*8
    bytes[start+1] = UInt8(i+1)
    bytes[start+2] = 1; bytes[start+3] = 1
    bytes[start+7] = UInt8(i+101)
}
let decoded = RegionalAMC.decode(bytes)!
precondition(decoded.sectors.count == 35 && decoded.issuerName == "Gemalto")
precondition(decoded.sectors[3].name == "Transports publics")
precondition(decoded.sectors[20].name == "Transports privés")
precondition(decoded.encodedDate == "06/08/2025" && decoded.signatureKeyReference == 0x1A01)
precondition(RegionalAMC.decode(Array(bytes.prefix(356))) == nil)
var broken = bytes; broken[13+8+1] = 1
precondition(RegionalAMC.decode(broken) == nil)
broken = bytes; broken[499] = 1
precondition(RegionalAMC.decode(broken) == nil)
broken = bytes; broken[8] = 0x19
precondition(RegionalAMC.decode(broken) == nil)
broken = bytes; broken[3] = 0x26
precondition(RegionalAMC.decode(broken) == nil)
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let profile = capture.regionalAMC!
    precondition(profile.issuerReference == 0xE002 && profile.sectors.count == 35)
    precondition(profile.sectors.map(\.id) == Array(1...35))
    precondition(profile.sectors.allSatisfy { $0.keyReference == 0x0101 })
    var conflict = capture
    conflict.exchanges.append(.init(operation: "READ BINARY PATH 22002203 / 0", response: "00", statusWord: "9000"))
    precondition(conflict.regionalAMC == nil)
    print("Private capture: common AMC, Gemalto issuer, 35 named sectors, key references and conflict rejection verified")
}
print("AMC: bounds, dates, duplicate sectors, trailing data and network scope tests passed")
