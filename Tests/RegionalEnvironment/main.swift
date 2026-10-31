import Foundation
func syntheticHex(_ fields: [(Int, Int)]) -> String {
    var bits = fields.map { value, width in
        let b = String(value, radix: 2)
        return String(repeating: "0", count: width - b.count) + b
    }.joined()
    bits += String(repeating: "0", count: (8 - bits.count % 8) % 8)
    var hex = ""
    while !bits.isEmpty {
        hex += String(format: "%02X", Int(bits.prefix(8), radix: 2)!)
        bits.removeFirst(8)
    }
    return hex
}
let sample = syntheticHex([(9,6),(7,7),(0x250920,24),(12,8),(14487,14),(130,8),(1,2),(0x20100102,32),(9,12),(2,4),(1,6)])
let env = RegionalEnvironment.decode(sample)!
precondition(env.versionLabel == "Intercode 2.1" && env.network == 0x250920 && env.issuer == 12)
precondition(env.expiryLabel == "31/08/2036" && env.personalizationLabel == "Nominative" && env.commercialCode == 1)
precondition(env.birthDate == "02/01/2010")
for bad in ["", "GG", "00", String(sample.prefix(20)), String(sample.dropLast(2)) + "01"] {
    precondition(RegionalEnvironment.decode(bad) == nil)
}
if CommandLine.arguments.count > 1 {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let capture = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let real = capture.regionalEnvironment!
    precondition(real.version == 9 && real.network == 0x250920 && real.issuer == 12)
    precondition(real.expiryDay == 14487 && real.personalization == 2 && real.commercialCode == 1 && real.birthDate != nil)
    print("Real report: environment, BCD birth date, technical expiry and personalization decoded")
}
print("RegionalEnvironment checks passed")
