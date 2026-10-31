import Foundation
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let inventories = capture.directInventories
precondition(inventories.map(\.fileCount) == [4, 11, 2, 19, 8, 7])
precondition(inventories.allSatisfy(\.endedNormally))
precondition(inventories.reduce(0) { $0 + $1.fileCount } == 51)
var replay = capture
let first = capture.exchanges.first { $0.operation == "ENUMERATE EF 1" }!
replay.exchanges.append(first)
precondition(replay.directInventories.first!.fileCount == 1)
precondition(!replay.directInventories.first!.endedNormally)
print("Direct inventory: six applications, 51 files, terminal replies and replay reset verified")
