import Foundation

struct RegionalApplicationAttempt: Identifiable {
    enum Outcome { case opened, absent, blocked, failed, untested }
    let id: String
    let outcome: Outcome
    let statusWord: String?
    var label: String {
        switch outcome {
        case .opened: return "Application ouverte"
        case .absent: return "Identifiant absent de la carte"
        case .blocked: return "Non ouverte · configuration NFC à compléter"
        case .failed: return "Sélection refusée · code " + (statusWord ?? "inconnu")
        case .untested: return "Pas encore testée"
        }
    }
}

extension RegionalCardCapture {
    /// One outcome per requested AID, rather than counting every re-selection
    /// of the same application during a long scan.
    var applicationAttempts: [RegionalApplicationAttempt] {
        (exploration?.applications ?? []).map { aid in
            let operation = "SELECT " + aid
            let selections = exchanges.filter { $0.operation == operation || $0.operation.hasPrefix(operation + " ") }
            if selections.contains(where: { $0.statusWord == "9000" }) {
                return .init(id: aid, outcome: .opened, statusWord: "9000")
            }
            if exploration?.undeclaredApplications?.contains(aid) == true {
                return .init(id: aid, outcome: .blocked, statusWord: nil)
            }
            guard let last = selections.last else { return .init(id: aid, outcome: .untested, statusWord: nil) }
            return .init(id: aid, outcome: last.statusWord == "6A82" ? .absent : .failed, statusWord: last.statusWord)
        }
    }
    var applicationSummary: String {
        let attempts = applicationAttempts
        if attempts.isEmpty { return "Aucune nouvelle application ajoutée à cette lecture" }
        let opened = attempts.filter { $0.outcome == .opened }.count
        let absent = attempts.filter { $0.outcome == .absent }.count
        let blocked = attempts.filter { $0.outcome == .blocked }.count
        let other = attempts.count - opened - absent - blocked
        return "\(opened) ouvertes · \(absent) absentes · \(blocked) non autorisées lors de cette lecture" + (other > 0 ? " · \(other) autres ou non testées" : "")
    }
    func newlySelectableApplications(declared: [String]) -> [String] {
        applicationAttempts.filter {
            $0.outcome == .blocked && RegionalApplicationAccess.permits($0.id, declared: declared)
        }.map(\.id)
    }
    /// A counter read is not a balance until the product's unit is established.
    func partialTitleCounter(_ pointer: Int) -> Int? {
        guard pointer > 0, let raw = ticketingRecords(sfi: 25, path: "20002069")?[1],
              raw.count >= pointer * 6 else { return nil }
        return Int(raw.dropFirst((pointer - 1) * 6).prefix(6), radix: 16)
    }
}
