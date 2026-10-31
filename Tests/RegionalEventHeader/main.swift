import Foundation

// Only timestamp prefixes, no card identifiers or personal record payloads.
let examples = [
    ("A9E5F8D0", "09/10/2026 à 16:49"),
    ("A9DE2D50", "07/10/2026 à 18:34"),
    ("A9728DD0", "10/09/2026 à 21:47")
]
for (hex, expected) in examples {
    precondition(RegionalEventHeader(hex: hex)?.label == expected)
}
for invalid in ["", "A9E5", "A9E5F8D", "A9E5F8DZ", "00000000", "FFFFFFFF", "A9E7FF80"] {
    precondition(RegionalEventHeader(hex: invalid) == nil, "Accepted invalid header: \(invalid)")
}
// Round-trip edges, including DST dates: retain the wall-clock value exactly.
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let epoch = calendar.date(from: DateComponents(year: 1997, month: 1, day: 1))!
for (month, day) in [(3, 29), (10, 25)] {
    let date = calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    let days = calendar.dateComponents([.day], from: epoch, to: date).day!
    for minute in [0, 149, 150, 1439] {
        let prefix = (UInt32(days) << 18) | (UInt32(minute) << 7)
        let header = RegionalEventHeader(hex: String(format: "%08X", prefix))!
        precondition(header.day == days && header.minutes == minute)
        precondition(header.label.hasSuffix(String(format: "%02d:%02d", minute / 60, minute % 60)))
    }
}
print("RegionalEventHeader: all checks passed")
