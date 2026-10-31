import Foundation
precondition(RegionalCardCapture().regionalPreferredJourneyHint == nil)
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    var report = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let hint = report.regionalPreferredJourneyHint!
    precondition(hint.contractID == 6 && hint.originCandidate == 8582 && hint.destinationCandidate == 13143)
    precondition(hint.saleDayCandidate == 10780 && hint.saleDeviceCandidate == 67)
    report.exchanges.removeAll { $0.operation.contains("20002001") || $0.operation.contains("SFI 07") || $0.operation.contains("APP 2001") }
    precondition(report.regionalPreferredJourneyHint == nil) // never apply outside the known network
    print("Real report: preferred-journey concordance scoped to network, right, raw pair and sale data")
}
print("Preferred journey hint checks passed")
