import Foundation

/// Experimental Intercode header, independent of Navigo lookups. Only the
/// date/time prefix is supported; it does not identify a station or a network.
struct RegionalEventHeader: Equatable {
    let day: Int
    let minutes: Int

    init?(day: Int, minutes: Int) {
        guard day > 0, day < 0x3FFF, minutes >= 0, minutes < 1440 else { return nil }
        self.day = day
        self.minutes = minutes
    }

    init?(hex: String) {
        guard hex.count >= 8, hex.count <= 512, hex.count.isMultiple(of: 2),
              hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let prefix = UInt32(hex.prefix(8), radix: 16) else { return nil }
        let day = Int(prefix >> 18)
        let minutes = Int((prefix >> 7) & 0x7FF)
        // Reserved/empty dates and impossible wall-clock times are not events.
        guard day > 0, day < 0x3FFF, minutes < 1440 else { return nil }
        self.day = day
        self.minutes = minutes
    }

    var label: String {
        // Format the calendar day independently of time-zone and DST conversion.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let epoch = calendar.date(from: DateComponents(year: 1997, month: 1, day: 1))!
        let date = calendar.date(byAdding: .day, value: day, to: epoch)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02d/%02d/%04d à %02d:%02d",
                      parts.day!, parts.month!, parts.year!, minutes / 60, minutes % 60)
    }
}
