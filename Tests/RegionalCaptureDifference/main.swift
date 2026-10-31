import Foundation

func report(_ card: String, _ entries: [(String, String)]) -> RegionalCardCapture {
    var capture = RegionalCardCapture()
    capture.exploration = .init(applications: ["test"], cardIdentifier: card)
    capture.exchanges = entries.map { .init(operation: $0.0, response: $0.1, statusWord: "9000") }
    return capture
}
let first = report("same", [("READ PATH 20002010 / 1", "AA"), ("READ PATH 20002030 / 1", "BB"), ("READ BINARY PATH 21002112 / 0", "00")])
let second = report("same", [("READ PATH 20002010 / 1", "CC"), ("READ PATH 20002010 / 1", "CC"), ("READ PATH 20002030 / 1", "BB"), ("READ PATH 21002115 / 1", "DD")])
let difference = RegionalCaptureDifference(previous: first, current: second)!
precondition(difference.changed == ["20002010 / 1"])
precondition(difference.added == ["21002115 / 1"])
precondition(difference.missing == ["Binaire 21002112 / 0"])
precondition(RegionalCaptureDifference(previous: first, current: report("different", [])) == nil)
let same = RegionalCaptureDifference(previous: first, current: first)!
precondition(same.added.isEmpty && same.changed.isEmpty && same.missing.isEmpty)
var conflict = second
conflict.exchanges.append(.init(operation: "READ PATH 20002010 / 1", response: "EE", statusWord: "9000"))
let uncertain = RegionalCaptureDifference(previous: first, current: conflict)!
precondition(uncertain.changed.isEmpty)
precondition(uncertain.missing.contains("20002010 / 1"))
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let unchanged = RegionalCaptureDifference(previous: capture, current: capture)!
    precondition(unchanged.changed.isEmpty && unchanged.added.isEmpty && unchanged.missing.isEmpty)
}
print("RegionalCaptureDifference: all checks passed")
