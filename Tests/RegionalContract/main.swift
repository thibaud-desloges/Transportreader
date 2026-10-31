import Foundation

func hex(_ fields: [(Int, Int)]) -> String {
    var bits = fields.map { value, width in
        let b = String(value, radix: 2)
        return String(repeating: "0", count: width - b.count) + b
    }.joined()
    bits += String(repeating: "0", count: (8 - bits.count % 8) % 8)
    var result = ""
    while !bits.isEmpty {
        result += String(format: "%02X", Int(bits.prefix(8), radix: 2)!)
        bits.removeFirst(8)
    }
    return result
}
let list = hex([(2, 4), (6, 3), (0xF208, 16), (5, 5), (6, 3), (0xF03C, 16), (6, 5)])
let references = RegionalContract.references(hex: list)!
precondition(references == [.init(pointer: 5, structure: 0x20, priority: 8), .init(pointer: 6, structure: 0x03, priority: 12)])
let full = hex([(63, 7), (29, 8), (123, 16), (456, 32), (2, 8), (3, 2), (10835, 14), (11199, 14), (1, 8)])
let compact = hex([(115, 7), (29, 8), (321, 16), (3, 2), (10835, 14), (11199, 14), (13, 8)])
let first = RegionalContract.decode(hex: full, reference: references[0])!
precondition(first.startDay == 10835 && first.endDay == 11199 && first.provider == 29 && first.tariff == 123)
precondition(first.validity == "Du 01/09/2026 au 31/08/2027")
precondition(RegionalContract.decode(hex: compact, reference: references[1])?.tariff == 321)
precondition(RegionalContract.decode(hex: full, reference: .init(pointer: 5, structure: 0xFF)) == nil)
for bad in ["", "00", "FFFF", "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", "GG", String(full.dropLast(4))] {
    precondition(RegionalContract.decode(hex: bad, reference: references[0]) == nil)
}
let reversed = hex([(115, 7), (29, 8), (321, 16), (3, 2), (11199, 14), (10835, 14), (13, 8)])
precondition(RegionalContract.decode(hex: reversed, reference: references[1]) == nil)
precondition(RegionalContract.references(hex: "2C") == nil)

var capture = RegionalCardCapture()
capture.selectedApplication = "334D54522E494341"
func add(_ operation: String, _ response: String, status: String = "9000") {
    capture.exchanges.append(.init(operation: operation, response: response, statusWord: status))
}
for record in 1...4 { add("READ SFI 09 / \(record)", "00000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF") }
add("READ SFI 06 / 1", full)
add("READ SFI 06 / 2", compact)
add("READ SFI 1E / 1", list)
precondition(capture.regionalContracts.map(\.id) == [5, 6])
add("READ PATH 20002030 / 1", full) // explicit path takes precedence over directory-scoped SFI
add("READ PATH 20002030 / 2", compact)
add("READ SFI 06 / 1", "00000000") // same SFI in another directory is unrelated
precondition(capture.regionalContracts.count == 2)
add("READ PATH 20002030 / 1", compact) // conflicting bytes must not be guessed
precondition(capture.regionalContracts.isEmpty)

// Optional local replay of a real report, without copying it into the repository.
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let report = try decoder.decode(RegionalCardCapture.self, from: data)
    let contracts = report.regionalContracts
    precondition(contracts.map(\.id) == [5, 6])
    precondition(contracts.allSatisfy { $0.startDay == 10835 && $0.endDay == 11199 })
    precondition(contracts[0].priceCents == 9000 && contracts[0].saleDay == 10780)
    precondition(contracts.map(\.status) == [1, 13])
    precondition(contracts.map(\.priority) == [8, 12])
    precondition(contracts[0].serialNumber == 8635 && contracts[0].saleDevice == 67 && contracts[0].saleAgent == 12)
    precondition(contracts[0].zones == 16128 && contracts[0].paymentMethod == 189)
    precondition(!contracts[0].hasUndecodedNonzeroBits && contracts[1].hasUndecodedNonzeroBits)
    print("Real report replay: two contracts, validity 01/09/2026–31/08/2027")
}
print("RegionalContract: all checks passed")
