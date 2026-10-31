import Foundation

/// Results of the independent sequential EF selection, not a physical-memory dump.
struct RegionalDirectInventory: Identifiable {
    let id: String
    let fileCount: Int
    let terminalStatus: String?
    var endedNormally: Bool { terminalStatus == "6A82" || terminalStatus == "6A83" }
    var label: String {
        let roots = ["334D54522E494341": "Racine", "A0000004040125092001": "2000",
                     "A0000004040225092001": "1000", "A0000004044125092001": "2300",
                     "A000000291A00000019102": "2100", "A000000291D25008009301": "2200"]
        return roots[id] ?? id
    }
}

extension RegionalCardCapture {
    var directInventories: [RegionalDirectInventory] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var endings: [String: String] = [:]
        for exchange in exchanges where exchange.operation.hasPrefix("ENUMERATE EF ") {
            let aid = exchange.application ?? selectedApplication
            if !order.contains(aid) { order.append(aid) }
            // A resumed session replays from FIRST_EF. Count its latest traversal,
            // rather than adding replayed descriptors a second time.
            if exchange.operation == "ENUMERATE EF 1" {
                counts[aid] = 0; endings[aid] = nil
            }
            if exchange.statusWord == "9000" {
                if RegionalFileHeader.decode(exchange.response, path: "") != nil {
                    counts[aid, default: 0] += 1
                } else { endings[aid] = "Format inconnu" }
            } else { endings[aid] = exchange.statusWord }
        }
        return order.map { .init(id: $0, fileCount: counts[$0] ?? 0, terminalStatus: endings[$0]) }
    }
}
