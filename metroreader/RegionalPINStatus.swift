import Foundation

/// Calypso's empty-data VERIFY command reads the presentation counter only.
/// No PIN value is supplied and no PIN presentation is performed.
enum RegionalPINStatus {
    static let operation = "READ PIN STATUS (aucun code présenté)"
    static let instruction: UInt8 = 0x20
    static let commandData = Data()
    // On the tested card, MF/3MTR advertises Prime Revision 2 (type 13),
    // while the 2300 application advertises Revision 3 (type 23).
    static func classByte(for aid: String) -> UInt8 {
        aid == "334D54522E494341" ? 0x94 : 0
    }
    static func label(statusWord: String) -> String {
        switch statusWord {
        // Keyple maps success in empty-data counter mode to three attempts.
        // The card returns a status word, not a literal count in its data bytes.
        case "9000": return "3 essais selon le décodage Calypso · réponse 9000 · aucun code présenté"
        case "63C2": return "2 essais restants · aucun code présenté"
        case "63C1": return "1 essai restant · aucun code présenté"
        case "6983": return "PIN bloqué · aucun code présenté"
        case "6D00": return "Fonction PIN non prise en charge"
        case "6985": return "État du PIN non accessible dans ce contexte"
        default: return "État non déterminé · réponse \(statusWord)"
        }
    }
}
