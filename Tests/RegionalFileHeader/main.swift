import Foundation
let pin = RegionalFileHeader.decode("85170204023001011000000102010100000000000000002302", path: "23002302")!
precondition(pin.requiresPIN && pin.recordSize == 48 && pin.recordCount == 1)
let shared = RegionalFileHeader.decode("851715040240101F0010000101030100211500000000002315", path: "23002315")!
precondition(!shared.requiresPIN && shared.sharedReference == 0x2115 && shared.recordCount == 16)
for bad in ["", "GG", "8517", String(repeating: "00", count: 25)] {
    precondition(RegionalFileHeader.decode(bad, path: "test") == nil)
}
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let headers = capture.regionalFileHeaders
    precondition(headers.count == 51)
    precondition(headers.filter(\.requiresPIN).map(\.path) == ["0003", "23002302"])
    let groups = Dictionary(grouping: headers.filter { $0.sharedReference != 0 }, by: \.sharedReference)
    precondition(groups.count == 8 && groups.values.allSatisfy { $0.count == 2 })
    print("Real capture: two PIN-protected files and eight pairs of shared files confirmed")
}
print("File header decoding checks passed")
