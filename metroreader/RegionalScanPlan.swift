import Foundation

/// A bounded public-file exploration, not an enumeration of every possible FID.
enum RegionalScanPlan {
    /// Probe the conventional xx00 directory address space. This is broader
    /// than a list of known folders, but still not all 65536 possible FIDs.
    static func directoryContexts(for aid: String) -> [[UInt8]] {
        let known = [0x2000, 0x2100, 0x3100, 0x1000, 0x8000]
        let values = aid == "334D54522E494341"
            ? known + (1...255).map { $0 << 8 }.filter { !known.contains($0) }
            : known
        return [[]] + values.map { [UInt8($0 >> 8), UInt8($0 & 255)] }
    }

    struct Location: Codable, Equatable {
        let sfi: Int?
        let path: [UInt8]?
        var relativeToApplication: Bool? = nil
        var directory: [UInt8]? = nil
        var label: String {
            if let sfi { return (directory.map { "DIRECTORY " + $0.map { String(format: "%02X", $0) }.joined() + " " } ?? "") + String(format: "SFI %02X", sfi) }
            return (relativeToApplication == true ? "PATH APP " : "PATH ") + (path ?? []).map { String(format: "%02X", $0) }.joined()
        }
    }

    static let locations: [Location] = {
        let priority = [7, 8, 9, 6, 30, 29, 25]
        let sfis = priority + (1...30).filter { !priority.contains($0) }
        let paths: [[UInt8]] = [
            [0x20, 0x00, 0x20, 0x20], [0x20, 0x00, 0x20, 0x30],
            [0x20, 0x00, 0x20, 0x50], [0x20, 0x00, 0x20, 0x01],
            [0x20, 0x00, 0x20, 0x02], [0x20, 0x00, 0x20, 0x04],
            [0x20, 0x00, 0x20, 0x10], [0x20, 0x00, 0x20, 0x40],
            [0x00, 0x02], [0x00, 0x03], [0x3F, 0x04], [0x3F, 0x1C], [0x2F, 0x10],
            [0x20, 0x00, 0x20, 0xF0],
            [0x21, 0x00, 0x21, 0x01], [0x21, 0x00, 0x21, 0x04],
            [0x21, 0x00, 0x21, 0x10], [0x21, 0x00, 0x21, 0x20],
            [0x21, 0x00, 0x21, 0x40], [0x21, 0x00, 0x21, 0x50],
            [0x21, 0x00, 0x21, 0x69], [0x21, 0x00, 0x21, 0xF0],
            [0x31, 0x00, 0x31, 0x02], [0x31, 0x00, 0x31, 0x04],
            [0x31, 0x00, 0x31, 0x15], [0x31, 0x00, 0x31, 0x20],
            [0x31, 0x00, 0x31, 0x13], [0x31, 0x00, 0x31, 0x23],
            [0x31, 0x00, 0x31, 0x33], [0x31, 0x00, 0x31, 0x50],
            [0x31, 0x00, 0x31, 0x69], [0x31, 0x00, 0x31, 0xF0],
            [0x10, 0x00, 0x10, 0x04], [0x10, 0x00, 0x10, 0x14],
            [0x10, 0x00, 0x10, 0x15], [0x80, 0x00, 0x80, 0x04],
            [0x80, 0x00, 0x80, 0x10], [0x80, 0x00, 0x80, 0x30]
        ] + (0x202A...0x202F).map { [0x20, 0x00, UInt8($0 >> 8), UInt8($0 & 255)] }
          + [0x2060, 0x2062, 0x2069, 0x206A].map { [0x20, 0x00, UInt8($0 >> 8), UInt8($0 & 255)] }
        return sfis.map { Location(sfi: $0, path: nil) }
            + paths.map { Location(sfi: nil, path: $0) }
    }()

    /// Ticketing files for the ordinary display, including the separate special
    /// event log observed on the older support. Never submits a PIN.
    static let quickLocations = [0x2001, 0x2010, 0x2020, 0x2030, 0x2050, 0x2040].map {
        Location(sfi: nil, path: [0x20, 0, UInt8($0 >> 8), UInt8($0 & 255)])
    }

    static func quickApplications(region: TransportRegion, initialAID: String) -> [String] {
        let preferred = region == .sud || region == .lignesAzur
            ? ["A0000004040125092001", initialAID, "334D54522E494341"]
            : [initialAID, "334D54522E494341", "315449432E494341"]
        var seen = Set<String>()
        return preferred.map { $0.uppercased() }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func inventoryApplications(initialAID: String) -> [String] {
        var seen = Set<String>()
        return ([initialAID, "334D54522E494341", "A0000004040125092001", "A0000004040225092001", "A0000004044125092001", "A000000291A00000019102", "A000000291D25008009301"])
            .map { $0.uppercased() }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Read directory-scoped SFIs that might be omitted from an optional EF list,
    /// plus the ISO application directory. Every SFI read reselects its directory.
    static let supplementaryLocations: [Location] = {
        let contexts: [[UInt8]] = [[0x20, 0], [0x21, 0], [0x22, 0], [0x23, 0], [0x10, 0]]
        return (1...30).map { Location(sfi: $0, path: nil) } + [Location(sfi: nil, path: [0x2F, 0x00])] + contexts.flatMap { context in
            (1...30).map { Location(sfi: $0, path: nil, directory: context) }
        }
    }()

    /// Public address discovery shared by every regional technology. Root SFIs,
    /// known ticketing paths and the ISO application directory are independent
    /// of the commercial network selected in the UI.
    static let researchLocations: [Location] = (1...30).map { Location(sfi: $0, path: nil) }
        + [Location(sfi: nil, path: [0x2F, 0x00])]
        + quickLocations
        + ([0x2001, 0x2010, 0x2020, 0x2030, 0x2050, 0x2040, 0x2017, 0x2069]).map {
            Location(sfi: nil, path: [UInt8($0 >> 8), UInt8($0 & 255)], relativeToApplication: true)
        }

    struct Cursor: Codable, Equatable {
        var applications: [String]
        var cardIdentifier: String
        var application = 0
        var location = 0
        var record = 1
        var binaryOffset = 0
        var binary = false
        var limitedFiles: [String] = []
        var directoryRead: Bool? = nil
        var additionalLocations: [Location]? = nil
        var directoryIndex: Int? = nil
        var supplementary: Bool? = nil
        var quick: Bool? = nil
        var applicationPrefixes: [String]? = nil
        var applicationPrefixIndex: Int? = nil
        var applicationPrefixSeen: [String]? = nil
        var knownApplicationIDs: [String]? = nil
        var knownApplicationNames: [String]? = nil
        var wideDirectories: Bool? = nil
        var enumerationCompleted: Bool? = nil
        var region: TransportRegion? = nil
        var supportOnly: Bool? = nil
        var pinStatus: Bool? = nil
        var pinStatusRead: Bool? = nil
        var enumeration: Bool? = nil
        var enumerationSeen: [String]? = nil
        var metadataIndex: Int? = nil
        var undeclaredApplications: [String]? = nil
        var locations: [Location] {
            if supportOnly == true { return [] }
            if pinStatus == true {
                let path: [UInt8] = applications[application] == "334D54522E494341" ? [0, 3] : [0x23, 0, 0x23, 2]
                return [Location(sfi: nil, path: path)]
            }
            if enumeration == true { return additionalLocations ?? [] }
            if wideDirectories == true { return RegionalScanPlan.researchLocations + (additionalLocations ?? []) }
            let mobib = RegionalScanPlan.quickLocations.map {
                Location(sfi: nil, path: Array(($0.path ?? []).suffix(2)), relativeToApplication: true)
            } + [0x2017, 0x2069].map { fid in
                Location(sfi: nil, path: [UInt8(fid >> 8), UInt8(fid & 255)], relativeToApplication: true)
            }
            let base = quick == true ? (region == .mobib ? mobib + RegionalScanPlan.quickLocations : RegionalScanPlan.quickLocations) : (supplementary == true ? RegionalScanPlan.supplementaryLocations : RegionalScanPlan.locations)
            return base + (additionalLocations ?? [])
        }
        var contexts: [[UInt8]] {
            if wideDirectories == true {
                return [[]] + (1...255).map { [UInt8($0), 0] }
            }
            return supplementary == true ? [[], [0x20, 0], [0x21, 0], [0x22, 0], [0x23, 0], [0x10, 0]] : RegionalScanPlan.directoryContexts(for: applications[application])
        }
        var finished: Bool {
            if let prefixes = applicationPrefixes, (applicationPrefixIndex ?? 0) < prefixes.count { return false }
            return application >= applications.count
        }

        mutating func nextLocation() {
            location += 1
            record = 1
            binaryOffset = 0
            binary = false
            if location >= locations.count { nextApplication() }
        }

        mutating func nextApplication() {
            application += 1
            location = 0
            record = 1
            binaryOffset = 0
            binary = false
            directoryRead = nil
            additionalLocations = nil
            directoryIndex = nil
            metadataIndex = nil
            enumerationSeen = nil
            enumerationCompleted = nil
            pinStatusRead = nil
        }
    }
}
