import Foundation

enum TransportRegion: String, CaseIterable, Identifiable, Codable {
    case ileDeFrance, sud, lignesAzur, oura, passPass, mobib
    static let settingKey = "selectedTransportRegion"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .ileDeFrance: return "Île-de-France"
        case .sud: return "Région Sud · PACA"
        case .lignesAzur: return "Nice · Côte d’Azur"
        case .oura: return "Auvergne-Rhône-Alpes"
        case .passPass: return "Hauts-de-France"
        case .mobib: return "Bruxelles · Belgique"
        }
    }
    var network: String {
        switch self {
        case .ileDeFrance: return "Navigo"
        case .sud: return "ZOU!"
        case .lignesAzur: return "Lignes d’Azur"
        case .oura: return "Oùra"
        case .passPass: return "Pass Pass"
        case .mobib: return "MOBIB"
        }
    }
    var logoAsset: String {
        switch self {
        case .ileDeFrance: return "IDFMSymbol"
        case .sud: return "ZouLogo"
        case .lignesAzur: return "LignesAzurLogo"
        case .oura: return "OuraLogo"
        case .passPass: return "PassPassLogo"
        case .mobib: return "MobibLogo"
        }
    }
    var cardAsset: String {
        switch self {
        case .ileDeFrance: return "Nominatif"
        case .lignesAzur: return "LignesAzurCard"
        case .oura: return "OuraCard"
        case .passPass: return "PassPassCard"
        case .mobib: return "MobibCard"
        default: return "ZouCard"
        }
    }
    var usesRegionalReader: Bool { self != .ileDeFrance }
}

extension RegionalCardCapture {
    /// The Nice support supplied by the passenger has issuer 25 in the shared
    /// Optima network. This is independent of codes of a title's issuer.
    var transportRegion: TransportRegion {
        if let uid = exploration?.cardIdentifier ?? nfcMetadata?.identifier,
           let confirmed = RegionalCardProfiles.confirmed[uid.uppercased()] { return confirmed }
        if ticketingNetworkID == 0x250920,
           let hex = ticketingRecords(sfi: 7, path: "20002001")?[1],
           hex.count >= 12, let prefix = UInt64(hex.prefix(12), radix: 16),
           (prefix >> 3) & 255 == 25 { return .lignesAzur }
        if nfcMetadata?.initialSelectedAID.uppercased().hasPrefix("315449432E494341D056") == true { return .mobib }
        return declaredRegion ?? .sud
    }
    func eventRouteName(_ event: RegionalEvent) -> String? {
        guard transportRegion == .passPass, ticketingNetworkID == 0x250000, event.provider == 23 else { return nil }
        switch event.route { case 100: return "Métro 1"; case 101: return "Métro 2"; case 102: return "Tram"; default: return nil }
    }
    func eventProviderName(_ code: Int) -> String? {
        if transportRegion == .passPass, ticketingNetworkID == 0x250000, code == 23 { return "Ilévia" }
        guard ticketingNetworkID == 0x250920 else { return nil }
        return [2: "TER", 25: "Lignes d’Azur"][code]
    }
}

/// Passenger-confirmed identities are private app data, never bundled card UIDs.
enum RegionalCardProfiles {
    static let fileName = "regional-card-profiles.json"
    static let confirmed: [String: TransportRegion] = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: TransportRegion].self, from: data) else { return [:] }
        return values.reduce(into: [:]) { $0[$1.key.uppercased()] = $1.value }
    }()
}

/// Confirmed associations within the regional rail ticketing context.
enum RegionalStationNames {
    static func name(code: Int, network: Int?) -> String? {
        guard network == 0x250920 else { return nil }
        switch code {
        case 8582: return "Marseille–Saint-Charles"
        case 13143: return "Toulon"
        case 16008: return "Les Arcs–Draguignan"
        default: return nil
        }
    }
}
