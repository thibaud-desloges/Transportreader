import Foundation

/// Compare only public reads of absolute file paths on the same NFC card.
/// These changes are evidence for further decoding, not proof of a new journey.
struct RegionalCaptureDifference {
    let added: [String]
    let changed: [String]
    let missing: [String]

    init?(previous: RegionalCardCapture, current: RegionalCardCapture) {
        guard let oldID = previous.exploration?.cardIdentifier, !oldID.isEmpty,
              oldID == current.exploration?.cardIdentifier else { return nil }
        func values(_ capture: RegionalCardCapture) -> [String: String] {
            var result: [String: String] = [:]
            var conflicts = Set<String>()
            for exchange in capture.exchanges {
                let parts = exchange.operation.split(separator: " ")
                guard exchange.statusWord == "9000" || exchange.statusWord == "6282",
                      !exchange.operation.contains("GET RESPONSE"),
                      !exchange.operation.contains("sélection") else { continue }
                let prefix: Int
                if parts.starts(with: ["READ", "PATH"]) { prefix = 2 }
                else if parts.starts(with: ["READ", "BINARY", "PATH"]) { prefix = 3 }
                else { continue }
                guard parts.count > prefix + 2, parts[prefix] != "APP",
                      UInt32(parts[prefix], radix: 16) != nil,
                      let record = Int(parts[prefix + 2]) else { continue }
                let key = "\(prefix == 3 ? "Binaire " : "")\(parts[prefix]) / \(record)"
                let value = exchange.response.uppercased()
                if let old = result[key], old != value { conflicts.insert(key) }
                result[key] = value
            }
            for key in conflicts { result.removeValue(forKey: key) }
            return result
        }
        let old = values(previous)
        let new = values(current)
        added = new.keys.filter { old[$0] == nil }.sorted()
        changed = new.keys.filter { old[$0] != nil && old[$0] != new[$0] }.sorted()
        missing = old.keys.filter { new[$0] == nil }.sorted()
    }
}
