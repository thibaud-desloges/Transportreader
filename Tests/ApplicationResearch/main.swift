import Foundation

let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "metroreader/metroreader/Info.plist")), format: nil) as! [String: Any]
let allowed = info[RegionalApplicationAccess.configurationKey] as! [String]
precondition(Set(allowed.map { $0.uppercased() }).count == allowed.count)
for (index, path) in CommandLine.arguments.dropFirst().enumerated() {
    var capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    capture.declaredRegion = index == 0 ? .mobib : .passPass
    let attempts = capture.applicationAttempts
    let expectedOpened = index == 0 ? 2 : 3
    let expectedBlocked = index == 0 ? 7 : 4
    let expectedAbsent = index == 0 ? 5 : 3
    precondition(attempts.filter { $0.outcome == .opened }.count == expectedOpened)
    precondition(attempts.filter { $0.outcome == .absent }.count == expectedAbsent)
    precondition(attempts.filter { $0.outcome == .blocked }.count == expectedBlocked)
    precondition(capture.newlySelectableApplications(declared: allowed).count == expectedBlocked)
    precondition(capture.newlySelectableApplications(declared: []).isEmpty)
    if index == 0 {
        precondition(capture.mobibEvents.count == 1 && capture.mobibTitles.first?.remainingJourneys == 4)
        precondition(capture.mobibTechnicalExpiryDay.map(RegionalContract.dateLabel) == "27/07/2029")
    } else {
        precondition(capture.regionalEvents.count == 6)
        precondition(capture.regionalEvents.filter { $0.result == 0 }.count == 2)
        precondition(capture.regionalEvents.filter { $0.result == nil }.count == 4)
        precondition(capture.regionalEvents.allSatisfy { $0.notOKCounter == nil })
        precondition(capture.partialTitleCounter(1) == 1432)
        precondition(capture.regionalUninterpretedTitles.first?.tariff == 25907)
    }
    print("Real research replay passed: \(expectedOpened) opened, \(expectedAbsent) absent, \(expectedBlocked) newly selectable; decoded content retained")
}
var sample = RegionalCardCapture()
sample.exploration = .init(applications: ["TEST-A", "TEST-B", "TEST-C", "TEST-D"], cardIdentifier: "synthetic")
sample.exploration?.undeclaredApplications = ["TEST-B"]
sample.exchanges = [
    .init(operation: "SELECT TEST-A", response: "", statusWord: "9000"),
    .init(operation: "SELECT TEST-A", response: "", statusWord: "9000"),
    .init(operation: "SELECT TEST-C", response: "", statusWord: "6A82"),
    .init(operation: "SELECT TEST-D", response: "", statusWord: "6985")
]
precondition(sample.applicationAttempts.map(\.outcome) == [.opened, .blocked, .absent, .failed])
precondition(sample.newlySelectableApplications(declared: ["TEST-B"]) == ["TEST-B"])
sample.exchanges.append(.init(operation: "SELECT TEST-B", response: "", statusWord: "9000"))
precondition(sample.newlySelectableApplications(declared: ["TEST-B"]).isEmpty)
// Failed-event fields remain raw, rather than becoming accepted validations.
var bits = [(8921,14), (820,11), (60,28), (49,8), (34,8), (23,8), (4,8)].map { value, width in
    String(repeating: "0", count: width - String(value, radix: 2).count) + String(value, radix: 2)
}.joined()
bits += String(repeating: "0", count: (8 - bits.count % 8) % 8)
var hex = ""
while !bits.isEmpty { hex += String(format: "%02X", Int(bits.prefix(8), radix: 2)!); bits.removeFirst(8) }
let failed = RegionalEvent.decode(hex: hex, record: 1)!
precondition(failed.result == 34 && failed.notOKCounter == 4)
print("Application outcome deduplication, selectable subset and failed-event raw fields passed")
