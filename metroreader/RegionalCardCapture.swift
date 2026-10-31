import Foundation

// Independent capture format: regional bytes must never enter Navigo parsers,
// station lookups or history until the card's actual data layout is established.
struct RegionalCardCapture: Codable {
    // Presentation-only fallback; original snapshots remain separately encoded.
    var priorReads: [RegionalCardCapture] = []
    private enum CodingKeys: String, CodingKey {
        case formatVersion, date, requestedNetwork, status, selectedApplication, exchanges, exploration, nfcMetadata, declaredRegion
    }
    var formatVersion = 6
    var date = Date()
    var requestedNetwork = "ZOU! — Région Sud"
    var status = "Lecture en cours"
    var selectedApplication = ""
    var exchanges: [Exchange] = []
    var exploration: RegionalScanPlan.Cursor? = nil
    var nfcMetadata: NFCMetadata? = nil
    var declaredRegion: TransportRegion? = nil
    var hasFileRead: Bool {
        exchanges.contains { $0.operation.hasPrefix("READ ") && ["9000", "6282"].contains($0.statusWord) && !$0.response.isEmpty }
    }

    struct NFCMetadata: Codable {
        let identifier: String
        let initialSelectedAID: String
        let historicalBytes: String?
        let applicationData: String?
        let proprietaryApplicationDataCoding: Bool
        var observedProtocol: String {
            let hasA = historicalBytes?.isEmpty == false
            let hasB = applicationData?.isEmpty == false
            if hasA && hasB { return "Métadonnées A et B fournies par iOS" }
            if hasB { return "ISO 14443 Type B observé" }
            if hasA { return "ISO 14443 Type A observé" }
            return "ISO 7816 · sous-type radio non déterminé"
        }
    }

    struct Exchange: Codable {
        let operation: String
        let response: String
        let statusWord: String
        var application: String? = nil
    }

    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

