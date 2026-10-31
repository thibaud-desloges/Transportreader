import Foundation
precondition(CommandLine.arguments.count == 3)
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let nice = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let zou = try decoder.decode(RegionalCardCapture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
precondition(nice.transportRegion == .lignesAzur && zou.transportRegion == .sud)
precondition(nice.regionalEvents.count == 1 && nice.regionalContracts.isEmpty)
let event = nice.regionalEvents[0]
precondition(event.mode == 4 && event.provider == 25 && event.route == 1 && event.vehicle == 1027)
precondition(nice.eventProviderName(25) == "Lignes d’Azur" && nice.eventProviderName(2) == "TER")
precondition(nice.eventProviderName(29) == nil)
precondition(nice.regionalPlace(for: event) == nil) // no SNCF station lookup
precondition(nice.regionalUninterpretedTitles.map(\.tariff) == [191, 99])
precondition(nice.regionalUninterpretedTitles.map(\.id) == [1, 5])
precondition(nice.regionalUninterpretedTitles.allSatisfy { $0.structure == 0x46 && $0.provider == 25 })
precondition(zou.regionalUninterpretedTitles.isEmpty && zou.regionalContracts.count == 2)
print("Lignes d’Azur: issuer-scoped detection, tram line 1, provider names and two structure-46 title headers passed; ZOU decoding preserved")
