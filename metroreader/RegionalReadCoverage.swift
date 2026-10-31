import Foundation

/// Coverage of the root EF descriptors actually enumerated in this capture.
/// Counts logical files per selected AID, not unique physical memory cells.
struct RegionalReadCoverage: Identifiable {
    let id: String
    let sfi: Int
    let expectedBytes: Int
    let coveredBytes: Int
    let refused: Bool
    var complete: Bool { coveredBytes == expectedBytes }
}

extension RegionalCardCapture {
    var enumeratedReadCoverage: [RegionalReadCoverage] {
        struct File {
            let aid: String
            let sfi: Int
            let binary: Bool
            let size: Int
            let count: Int
            var covered = Set<Int>()
            var refused = false
        }
        var files: [String: File] = [:]
        var paths: [String: String] = [:]
        for exchange in exchanges where exchange.statusWord == "9000" {
            let aid = exchange.application ?? selectedApplication
            let hex = exchange.response.uppercased()
            guard let header = RegionalFileHeader.decode(hex, path: ""),
                  let sfi = Int(hex.dropFirst(4).prefix(2), radix: 16),
                  let kind = Int(hex.dropFirst(8).prefix(2), radix: 16) else { continue }
            let key = aid + ":" + hex
            if exchange.operation.hasPrefix("ENUMERATE EF ") {
                files[key] = .init(aid: aid, sfi: sfi, binary: kind == 1, size: header.recordSize, count: header.recordCount)
            }
            if exchange.operation.hasPrefix("SELECT PATH APP ") {
                paths[aid + ":" + exchange.operation.dropFirst("SELECT PATH APP ".count)] = key
            }
        }
        for exchange in exchanges {
            var operation = exchange.operation
            guard operation.hasPrefix("READ ") else { continue }
            operation.removeFirst(5)
            let binary = operation.hasPrefix("BINARY ")
            if binary { operation.removeFirst(7) }
            let parts = operation.components(separatedBy: " / ")
            guard parts.count == 2, let token = parts[1].split(separator: " ").first, let index = Int(token) else { continue }
            let aid = exchange.application ?? selectedApplication
            let keys: [String]
            if parts[0].hasPrefix("SFI "), let sfi = Int(parts[0].dropFirst(4), radix: 16) {
                keys = files.filter { $0.value.aid == aid && $0.value.sfi == sfi }.map(\.key)
                // An ambiguous SFI mapping is not evidence of either file's content.
                if keys.count != 1 { continue }
            } else if parts[0].hasPrefix("PATH APP "), let key = paths[aid + ":" + parts[0].dropFirst(9)] {
                keys = [key]
            } else { continue }
            for key in keys {
                guard var file = files[key] else { continue }
                if ["6982", "6985"].contains(exchange.statusWord) { file.refused = true }
                if ["9000", "6282"].contains(exchange.statusWord), binary == file.binary,
                   binary || (1...max(file.count, 1)).contains(index) {
                    let start = binary ? index : (index - 1) * file.size
                    let end = min(file.size * file.count, start + exchange.response.count / 2)
                    if start >= 0 && end >= start { file.covered.formUnion(start..<end) }
                }
                files[key] = file
            }
        }
        return files.map { key, file in
            .init(id: key, sfi: file.sfi, expectedBytes: file.size * file.count,
                  coveredBytes: file.covered.count, refused: file.refused && file.covered.count < file.size * file.count)
        }.sorted { $0.id < $1.id }
    }
}
