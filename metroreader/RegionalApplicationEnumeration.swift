import Foundation

/// ISO 7816-4 selection by DF-name prefix, FIRST (P2=00) / NEXT (P2=02).
/// Scope is explicit: these four families are not the whole possible AID space.
enum RegionalApplicationEnumeration {
    static let prefixes = ["A000000291", "A000000404", "315449432E", "334D54522E"]
    static let maximumOccurrences = 64
    static func selectedAID(response: Data, prefix: String) -> String? {
        RegionalApplicationDirectory.identifiers(response)?.first { $0.hasPrefix(prefix) }
    }
}

struct RegionalApplicationFamilyResult: Identifiable {
    let id: String
    let applicationCount: Int
    let ended: Bool
    let repeated: Bool
    let lastStatus: String?
    var missingKnownNames = 0
    var label: String {
        if ended { return "\(applicationCount) applications · fin de liste annoncée" }
        if missingKnownNames > 0 { return "\(applicationCount) applications · \(missingKnownNames) noms connus non retournés, fin non confirmée" }
        if repeated { return "\(applicationCount) applications · répétition, fin non confirmée" }
        return "\(applicationCount) applications · fin non confirmée" + (lastStatus.map { " (\($0))" } ?? "")
    }
}

extension RegionalCardCapture {
    var applicationFamilyResults: [RegionalApplicationFamilyResult] {
        (exploration?.applicationPrefixes ?? []).map { prefix in
            let start = "SELECT APPLICATION OCCURRENCE \(prefix) / "
            let assembledStart = "APPLICATION ENUMERATION RESULT \(prefix) / "
            let assembled = exchanges.filter { $0.operation.hasPrefix(assembledStart) }
            let actualStart = assembled.isEmpty ? start : assembledStart
            let replies = assembled.isEmpty ? exchanges.filter { $0.operation.hasPrefix(start) } : assembled
            var seen = Set<String>(), repeated = false
            // A new FIRST selection starts a fresh traversal after an NFC pause.
            var traversal = Set<String>()
            for reply in replies {
                if reply.operation == actualStart + "0" { traversal = []; repeated = false }
                if reply.statusWord == "9000", let data = Data(hexStringForEnumeration: reply.response),
                   let aid = RegionalApplicationEnumeration.selectedAID(response: data, prefix: prefix) {
                    seen.insert(aid)
                    if !traversal.insert(aid).inserted { repeated = true }
                }
            }
            let expected = Set((exploration?.knownApplicationNames ?? []).filter { $0.hasPrefix(prefix) })
            let missing = expected.subtracting(seen).count
            let knownFamily = exploration?.knownApplicationIDs?.contains(where: { $0.hasPrefix(prefix) }) == true
            let emptyContradiction = seen.isEmpty && knownFamily
            return .init(id: prefix, applicationCount: seen.count,
                         ended: replies.last?.statusWord == "6A82" && missing == 0 && !emptyContradiction,
                         repeated: repeated, lastStatus: replies.last?.statusWord,
                         missingKnownNames: max(missing, emptyContradiction ? 1 : 0))
        }
    }
}

private extension Data {
    init?(hexStringForEnumeration value: String) {
        guard value.count.isMultiple(of: 2), value.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        self.init()
        var index = value.startIndex
        while index < value.endIndex {
            let end = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<end], radix: 16) else { return nil }
            append(byte); index = end
        }
    }
}
