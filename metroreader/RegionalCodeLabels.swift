import Foundation

/// Passenger annotations stay separate from decoded card bytes. A code is scoped
/// by network and field: a contract supplier is not an event operator.
struct RegionalCodeLabels: Codable, Equatable {
    private var labels: [String: String] = [:]

    private func key(network: Int, field: String, code: Int) -> String {
        "\(network):\(field):\(code)"
    }
    func label(network: Int, field: String, code: Int) -> String? {
        labels[key(network: network, field: field, code: code)]
    }
    mutating func set(_ text: String, network: Int, field: String, code: Int) {
        let value = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        labels[key(network: network, field: field, code: code)] = value.isEmpty ? nil : value
    }
    init() {}
    init(json: String) {
        self = (try? JSONDecoder().decode(Self.self, from: Data(json.utf8))) ?? Self()
    }
    var json: String {
        guard let data = try? JSONEncoder().encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
