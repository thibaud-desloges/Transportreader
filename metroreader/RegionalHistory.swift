import Foundation
import Combine

struct RegionalHistoryRecord: Codable, Identifiable {
    var id: String
    var date: Date
    var capture: RegionalCardCapture
    var scans: [RegionalCardCapture]? = nil
    var lastReadDate: Date? = nil
    var nickname: String? = nil
    var imageName: String? = nil
    var displayTitle: String { nickname.flatMap { $0.isEmpty ? nil : $0 } ?? "Carte \(capture.transportRegion.network)" }
    var mostRecentDate: Date { lastReadDate ?? capture.date }
}

/// Regional captures stay outside Navigo parsers and use the same history opt-in.
final class RegionalHistory: ObservableObject {
    static let shared = RegionalHistory()
    @Published private(set) var records: [RegionalHistoryRecord] = []
    @Published private(set) var error: String?
    private let url: URL
    private var writable = true

    init(url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("regional-history.json")) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let saved = try decoder.decode([RegionalHistoryRecord].self, from: Data(contentsOf: url))
            records = Self.grouped(saved)
            // Keep a recoverable, exact copy before the one-time UID migration.
            if saved.map(\.id) != records.map(\.id) {
                let backup = url.appendingPathExtension("before-card-grouping.json")
                if !FileManager.default.fileExists(atPath: backup.path) { try Data(contentsOf: url).write(to: backup, options: [.atomic, .completeFileProtection]) }
                persist(records)
            }
        } catch {
            writable = false
            self.error = "L’historique régional n’a pas pu être relu. Son fichier est conservé."
        }
    }

    func save(_ capture: RegionalCardCapture, enabled: Bool) {
        guard enabled, writable, let cursor = capture.exploration, cursor.finished,
              !capture.exchanges.isEmpty else { return }
        let id = Self.identity(capture) ?? (cursor.cardIdentifier + ":" + ISO8601DateFormatter().string(from: capture.date))
        let record = RegionalHistoryRecord(id: id, date: capture.date, capture: capture)
        persist(Self.grouped(records + [record]))
    }

    private static func identity(_ capture: RegionalCardCapture) -> String? {
        guard let uid = capture.exploration?.cardIdentifier, !uid.isEmpty else { return nil }
        return "card:" + uid.uppercased()
    }

    private static func grouped(_ input: [RegionalHistoryRecord]) -> [RegionalHistoryRecord] {
        var grouped: [String: RegionalHistoryRecord] = [:]
        for record in input.sorted(by: { $0.date < $1.date }) {
            let id = identity(record.capture) ?? record.id
            let previous = grouped[id]
            var scans = previous?.scans ?? previous.map { [$0.capture] } ?? []
            for scan in record.scans ?? [record.capture] {
                let key = ISO8601DateFormatter().string(from: scan.date)
                if let i = scans.firstIndex(where: { ISO8601DateFormatter().string(from: $0.date) == key }) {
                    // A resumed scan is a more complete snapshot of the same read.
                    if scan.exchanges.count >= scans[i].exchanges.count { scans[i] = scan }
                } else { scans.append(scan) }
            }
            scans.sort { $0.date < $1.date }
            var latest = scans.last ?? record.capture
            latest.priorReads = scans.dropLast().map { scan in var raw = scan; raw.priorReads = []; return raw }
            grouped[id] = .init(id: id, date: min(previous?.date ?? record.date, record.date),
                                capture: latest, scans: scans, lastReadDate: latest.date,
                                nickname: record.nickname ?? previous?.nickname,
                                imageName: record.imageName ?? previous?.imageName)
        }
        return grouped.values.sorted { $0.mostRecentDate > $1.mostRecentDate }
    }

    func personalize(_ id: String, nickname: String? = nil, imageName: String? = nil) {
        var updated = records
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        if let nickname { updated[index].nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let imageName { updated[index].imageName = imageName }
        persist(updated)
    }

    func delete(_ ids: Set<String>) { persist(records.filter { !ids.contains($0.id) }) }
    func clearAll() {
        do {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            records = []; writable = true; error = nil
        } catch { self.error = "L’historique régional n’a pas pu être effacé." }
    }
    private func persist(_ updated: [RegionalHistoryRecord]) {
        guard writable else { return }
        do {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(updated).write(to: url, options: [.atomic, .completeFileProtection])
            records = updated; error = nil
        } catch { self.error = "L’historique régional n’a pas pu être enregistré." }
    }
}
