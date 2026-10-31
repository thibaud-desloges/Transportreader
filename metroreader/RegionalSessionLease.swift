import Foundation

/// Identify one live NFC run. Replies from a cancelled session cannot modify
/// the next run or close it after the user taps Resume.
struct RegionalSessionLease {
    private(set) var current: UUID?
    mutating func begin() -> UUID {
        let token = UUID()
        current = token
        return token
    }
    func accepts(_ token: UUID) -> Bool { current == token }
    mutating func end() { current = nil }
}
