import Foundation

extension RegionalCardCapture {
    /// Both identifiers were observed selecting the same ticketing files on the
    /// tested card. Prefer explicit paths: an SFI is scoped to the current
    /// directory and can identify a different file under the MF application.
    /// Require all successful copies within the chosen addressing tier to agree.
    func ticketingRecords(sfi: Int, path: String, includingPrevious: Bool = true) -> [Int: String]? {
        let prefixes = [String(format: "READ SFI %02X / ", sfi),
                        "READ PATH \(path) / ", "READ PATH APP \(path.suffix(4)) / ",
                        String(format: "READ DIRECTORY 2000 SFI %02X / ", sfi)]
        let explicit = exchanges.filter {
            $0.statusWord == "9000" &&
            ($0.operation.hasPrefix(prefixes[1]) || $0.operation.hasPrefix(prefixes[3]) ||
             ($0.application == "A0000004040125092001" && $0.operation.hasPrefix(prefixes[2])))
        }
        let candidates = explicit.isEmpty ? exchanges : explicit
        var result: [Int: String] = [:]
        for exchange in candidates {
            let aid = (exchange.application ?? selectedApplication).uppercased()
            guard ["334D54522E494341", "A0000004040125092001",
                   "A0000004040125000001000000000000"].contains(aid),
                  exchange.statusWord == "9000", !exchange.operation.contains("GET RESPONSE"),
                  let prefix = prefixes.first(where: { exchange.operation.hasPrefix($0) }),
                  let token = exchange.operation.dropFirst(prefix.count).split(separator: " ").first,
                  let record = Int(token), (1...254).contains(record) else { continue }
            // APP paths refer to the selected application's root. Only the
            // explicit ticketing AID roots at 2000; 3MTR roots at the card MF.
            if prefix.hasPrefix("READ PATH APP"), aid != "A0000004040125092001" { continue }
            let bytes = exchange.response.uppercased()
            if let old = result[record], old != bytes { return nil }
            result[record] = bytes
        }
        if result.isEmpty && includingPrevious, let uid = exploration?.cardIdentifier {
            for earlier in priorReads.sorted(by: { $0.date > $1.date }) where earlier.exploration?.cardIdentifier == uid {
                if let values = earlier.ticketingRecords(sfi: sfi, path: path, includingPrevious: false), !values.isEmpty { return values }
            }
        }
        return result
    }

    var usesEarlierTicketingReads: Bool {
        [(7, "20002001"), (8, "20002010"), (9, "20002020"), (6, "20002030"), (30, "20002050"), (29, "20002040")].contains { sfi, path in
            ticketingRecords(sfi: sfi, path: path, includingPrevious: false)?.isEmpty == true &&
            ticketingRecords(sfi: sfi, path: path)?.isEmpty == false
        }
    }

    var ticketingNetworkID: Int? {
        guard let hex = ticketingRecords(sfi: 7, path: "20002001")?[1],
              hex.count >= 10, let prefix = UInt64(hex.prefix(10), radix: 16),
              ((prefix >> 27) & 1) == 1 else { return nil }
        return Int((prefix >> 3) & 0xFFFFFF)
    }
}
