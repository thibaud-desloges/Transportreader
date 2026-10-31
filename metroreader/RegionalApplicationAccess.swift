import Foundation

/// CoreNFC requires every selected AID to be declared in the installed app.
/// Discovering an AID on a card cannot grant the app that permission at runtime.
enum RegionalApplicationAccess {
    static let configurationKey = "com.apple.developer.nfc.readersession.iso7816.select-identifiers"
    static func permits(_ aid: String, declared: [String]) -> Bool {
        declared.contains { $0.uppercased() == aid.uppercased() }
    }
}
