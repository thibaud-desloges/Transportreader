import Foundation
import SwiftUI

#if os(iOS)
import CoreNFC

/// Public reads only. State is checkpointed so a later presentation can resume.
final class RegionalCardReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    static let shared = RegionalCardReader()
    @Published private(set) var capture: RegionalCardCapture?
    @Published private(set) var previousCapture: RegionalCardCapture?
    @Published private(set) var isScanning = false
    @Published private(set) var isTagDetected = false
    @Published private(set) var showsFreshRead = false
    func prepareForNewCard() { showsFreshRead = false }
    @Published private(set) var message = "Prêt pour une lecture approfondie."
    private var session: NFCTagReaderSession?
    private var activeApplication: String?
    private var resumeRequested = false
    private var quickRequested = false
    private var inventoryRequested = false
    private var researchRequested = false
    private var busyRetryCount = 0
    private var expectedCardIdentifier: String?
    private var deadline = Date.distantFuture
    private var lease = RegionalSessionLease()
    private struct Pause: Error {}
    private struct ObsoleteSession: Error {}
    private struct Response { let data: Data; let status: UInt16 }

    private static var savedURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("regional-deep-scan.json")
    }

    private static var previousURL: URL {
        savedURL.deletingLastPathComponent().appendingPathComponent("regional-previous-scan.json")
    }

    override init() {
        super.init()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: Self.savedURL),
           let saved = try? decoder.decode(RegionalCardCapture.self, from: data) {
            capture = saved
            message = saved.exploration?.finished == true
                ? "Recherches prévues terminées. Cela ne garantit pas une copie complète de la carte."
                : saved.status
        }
        if let data = try? Data(contentsOf: Self.previousURL) {
            previousCapture = try? decoder.decode(RegionalCardCapture.self, from: data)
        }
    }

    var canResume: Bool {
        guard let cursor = capture?.exploration else { return false }
        return !cursor.finished
    }

    private func save() {
        guard let capture, let data = capture.json.data(using: .utf8) else { return }
        do { try data.write(to: Self.savedURL, options: [.atomic, .completeFileProtection]) }
        catch { message += " Le rapport n’a pas pu être sauvegardé : partagez-le avant de fermer." }
    }

    func start(resuming: Bool = false, quick: Bool = false, inventory: Bool = false, research: Bool = false, expectedCardIdentifier: String? = nil) {
        guard !isScanning else { return }
        // A finished NFCTagReaderSession is single-use. Release a stale handle
        // rather than silently refusing the Resume button until its callback.
        let previousSession = session
        session = nil
        lease.end()
        previousSession?.invalidate()
        guard NFCTagReaderSession.readingAvailable else {
            message = "La lecture NFC nécessite un iPhone compatible."
            return
        }
        quickRequested = quick
        showsFreshRead = false
        inventoryRequested = inventory
        researchRequested = research
        busyRetryCount = 0
        self.expectedCardIdentifier = expectedCardIdentifier
        resumeRequested = resuming && canResume
        if !resumeRequested {
            if let old = capture, !old.exchanges.isEmpty {
                do {
                    try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection])
                    previousCapture = old
                } catch {
                    message = "Impossible de conserver la lecture précédente. Partagez le rapport puis réessayez."
                    return
                }
            }
            capture = RegionalCardCapture()
            if let region = TransportRegion(rawValue: UserDefaults.standard.string(forKey: TransportRegion.settingKey) ?? "") {
                capture?.requestedNetwork = region.network
                capture?.declaredRegion = region
            }
        }
        activeApplication = nil
        isTagDetected = false
        isScanning = true
        message = "Ouverture du lecteur NFC…"
        openSession(after: 0.8)
    }

    private func openSession(after delay: TimeInterval) {
        guard isScanning else { return }
        guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: .main) else {
            finish("Impossible d’ouvrir une session NFC."); return
        }
        self.session = session
        let token = lease.begin()
        session.alertMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak session] in
            guard let self, self.lease.accepts(token), let session else { return }
            session.begin()
        }
    }

    func deepen(from source: RegionalCardCapture? = nil) {
        guard !isScanning, let old = source ?? capture,
              let oldCursor = old.exploration, oldCursor.finished else { return }
        do { try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection]) }
        catch { message = "Impossible de sauvegarder le rapport actuel."; return }
        previousCapture = old
        var fresh = RegionalCardCapture()
        fresh.declaredRegion = old.transportRegion
        fresh.requestedNetwork = old.transportRegion.network
        fresh.nfcMetadata = old.nfcMetadata
        var raw = old; raw.priorReads = []
        fresh.priorReads = [raw] + old.priorReads
        var next = RegionalScanPlan.Cursor(applications: RegionalScanPlan.inventoryApplications(initialAID: old.nfcMetadata?.initialSelectedAID ?? old.selectedApplication), cardIdentifier: oldCursor.cardIdentifier)
        next.region = old.transportRegion
        next.supplementary = true
        next.wideDirectories = true
        fresh.exploration = next
        capture = fresh
        save()
        start(resuming: true, expectedCardIdentifier: oldCursor.cardIdentifier)
    }

    /// Read only applications previously discovered but unavailable to the
    /// installed NFC configuration. Historical reports remain separate snapshots.
    func readNewApplications(from old: RegionalCardCapture) {
        guard !isScanning, let oldCursor = old.exploration, oldCursor.finished else { return }
        let declared = Bundle.main.object(forInfoDictionaryKey: RegionalApplicationAccess.configurationKey) as? [String] ?? []
        let aids = old.newlySelectableApplications(declared: declared)
        guard !aids.isEmpty else { message = "Aucune nouvelle application à lire."; return }
        do { try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection]) }
        catch { message = "Impossible de conserver la lecture précédente."; return }
        previousCapture = old
        var fresh = RegionalCardCapture()
        fresh.declaredRegion = old.transportRegion; fresh.requestedNetwork = old.transportRegion.network
        fresh.nfcMetadata = old.nfcMetadata
        var raw = old; raw.priorReads = []
        fresh.priorReads = [raw] + old.priorReads
        var cursor = RegionalScanPlan.Cursor(applications: aids, cardIdentifier: oldCursor.cardIdentifier)
        cursor.region = old.transportRegion; cursor.enumeration = true
        fresh.exploration = cursor
        capture = fresh; save()
        start(resuming: true, expectedCardIdentifier: oldCursor.cardIdentifier)
    }

    func enumerateApplicationFamilies(from old: RegionalCardCapture) {
        guard !isScanning, let oldCursor = old.exploration, oldCursor.finished else { return }
        do { try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection]) }
        catch { message = "Impossible de conserver la lecture précédente."; return }
        previousCapture = old
        var fresh = RegionalCardCapture()
        fresh.declaredRegion = old.transportRegion; fresh.requestedNetwork = old.transportRegion.network
        fresh.nfcMetadata = old.nfcMetadata
        var raw = old; raw.priorReads = []
        fresh.priorReads = [raw] + old.priorReads
        var cursor = RegionalScanPlan.Cursor(applications: [], cardIdentifier: oldCursor.cardIdentifier)
        cursor.region = old.transportRegion; cursor.enumeration = true
        cursor.applicationPrefixes = RegionalApplicationEnumeration.prefixes
        cursor.knownApplicationIDs = Array(Set(([old] + old.priorReads).flatMap {
            $0.applicationAttempts.filter { $0.outcome == .opened }.map(\.id)
        }))
        cursor.knownApplicationNames = Array(Set(([old] + old.priorReads).flatMap { scan in
            let selectedOperations = Set(scan.applicationAttempts.filter { $0.outcome == .opened }.map { "SELECT " + $0.id })
            return scan.exchanges.compactMap { exchange -> String? in
                guard exchange.statusWord == "9000", selectedOperations.contains(exchange.operation),
                      let bytes = Self.hexData(exchange.response) else { return nil }
                return RegionalApplicationDirectory.identifiers(bytes)?.first
            }
        }))
        fresh.exploration = cursor; capture = fresh; save()
        start(resuming: true, expectedCardIdentifier: oldCursor.cardIdentifier)
    }

    private static func hexData(_ value: String) -> Data? {
        guard value.count.isMultiple(of: 2), value.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        let chars = Array(value)
        return Data(stride(from: 0, to: chars.count, by: 2).map { UInt8(String(chars[$0...$0+1]), radix: 16)! })
    }

    private func discoverApplicationOccurrences(_ card: NFCISO7816Tag) async throws {
        while let cursor = capture?.exploration, let prefixes = cursor.applicationPrefixes,
              (cursor.applicationPrefixIndex ?? 0) < prefixes.count {
            let prefixIndex = cursor.applicationPrefixIndex ?? 0
            let prefix = prefixes[prefixIndex]
            let declared = Bundle.main.object(forInfoDictionaryKey: RegionalApplicationAccess.configurationKey) as? [String] ?? []
            guard RegionalApplicationAccess.permits(prefix, declared: declared) else {
                capture?.exploration?.limitedFiles.append("Famille \(prefix) non autorisée par la configuration NFC")
                capture?.exploration?.applicationPrefixIndex = prefixIndex + 1
                capture?.exploration?.applicationPrefixSeen = []; save(); continue
            }
            let chars = Array(prefix)
            let bytes = Data(stride(from: 0, to: chars.count, by: 2).map { UInt8(String(chars[$0...$0+1]), radix: 16)! })
            var complete = false
            // Replay FIRST/NEXT after a pause: the card's selection cursor is
            // volatile, while the observed application names are checkpointed.
            for occurrence in 0..<RegionalApplicationEnumeration.maximumOccurrences {
                message = "Vérification des applications · famille \(prefixIndex + 1)/\(prefixes.count) · position \(occurrence + 1)"
                session?.alertMessage = message
                activeApplication = prefix
                let response = try await exchange(card, instruction: 0xA4, p1: 4, p2: occurrence == 0 ? 0 : 2,
                    data: bytes, name: "SELECT APPLICATION OCCURRENCE \(prefix) / \(occurrence)")
                // Keep the assembled FCI as evidence even when GET RESPONSE
                // split it across several APDUs.
                capture?.exchanges.append(.init(operation: "APPLICATION ENUMERATION RESULT \(prefix) / \(occurrence)",
                    response: response.data.map { String(format: "%02X", $0) }.joined(),
                    statusWord: String(format: "%04X", response.status), application: prefix))
                guard response.status == 0x9000 else {
                    if response.status != 0x6A82 {
                        capture?.exploration?.limitedFiles.append(String(format: "Famille %@ : fin non confirmée (%04X)", prefix, response.status))
                    }
                    complete = true; break
                }
                guard let aid = RegionalApplicationEnumeration.selectedAID(response: response.data, prefix: prefix) else {
                    capture?.exploration?.limitedFiles.append("Famille \(prefix) : réponse sans nom d’application exploitable")
                    complete = true; break
                }
                let seen = capture?.exploration?.applicationPrefixSeen ?? []
                if occurrence < seen.count {
                    guard seen[occurrence] == aid else {
                        capture?.exploration?.limitedFiles.append("Famille \(prefix) : ordre modifié pendant la reprise")
                        complete = true; break
                    }
                } else {
                    guard !seen.contains(aid) else {
                        capture?.exploration?.limitedFiles.append("Famille \(prefix) : répétition, fin non confirmée")
                        complete = true; break
                    }
                    if capture?.exploration?.applicationPrefixSeen == nil { capture?.exploration?.applicationPrefixSeen = [] }
                    capture?.exploration?.applicationPrefixSeen?.append(aid)
                    if !(capture?.exploration?.knownApplicationIDs?.contains(aid) ?? false),
                       !(capture?.exploration?.applications.contains(aid) ?? false) {
                        if (capture?.exploration?.applications.count ?? 0) < 64 {
                            capture?.exploration?.applications.append(aid)
                        } else { capture?.exploration?.limitedFiles.append("Limite de 64 nouvelles applications atteinte") }
                    }
                }
                save()
            }
            if !complete { capture?.exploration?.limitedFiles.append("Famille \(prefix) : limite d’énumération atteinte") }
            capture?.exploration?.applicationPrefixIndex = prefixIndex + 1
            capture?.exploration?.applicationPrefixSeen = []; save()
        }
    }

    /// Independent FIRST EF / NEXT EF inventory, preserving the existing capture.
    func enumerateFiles() {
        guard !isScanning, let old = capture, let cursor = old.exploration, cursor.finished else { return }
        do {
            try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection])
        } catch { message = "Impossible de sauvegarder le rapport actuel."; return }
        previousCapture = old
        var next = RegionalScanPlan.Cursor(applications: RegionalScanPlan.inventoryApplications(initialAID: old.nfcMetadata?.initialSelectedAID ?? ""), cardIdentifier: cursor.cardIdentifier)
        next.region = old.transportRegion
        next.enumeration = true
        capture?.exploration = next
        save()
        start(resuming: true)
    }

    /// Native discovery metadata only; retain every previously read card file.
    func inspectSupport() {
        guard !isScanning, let old = capture, let cursor = old.exploration, cursor.finished else { return }
        do {
            try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection])
        } catch { message = "Impossible de sauvegarder le rapport actuel."; return }
        previousCapture = old
        var next = RegionalScanPlan.Cursor(applications: ["A0000004040125092001"], cardIdentifier: cursor.cardIdentifier)
        next.supportOnly = true
        capture?.exploration = next
        save()
        start(resuming: true)
    }

    func checkProtectedAccess() {
        guard !isScanning, let old = capture, let cursor = old.exploration, cursor.finished else { return }
        do {
            try Data(old.json.utf8).write(to: Self.previousURL, options: [.atomic, .completeFileProtection])
        } catch {
            message = "Impossible de sauvegarder le rapport actuel."
            return
        }
        previousCapture = old
        var next = RegionalScanPlan.Cursor(applications: ["334D54522E494341", "A0000004044125092001"], cardIdentifier: cursor.cardIdentifier)
        next.pinStatus = true
        capture?.exploration = next
        save()
        start(resuming: true)
    }

    func stop() {
        guard let session else { return }
        finish("Lecture arrêtée. Le rapport est sauvegardé ; la recherche peut reprendre.")
        session.invalidate()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        DispatchQueue.main.async {
            guard self.session === session, self.isScanning else { return }
            self.message = "Placez votre carte de transport contre le haut de l’iPhone."
            session.alertMessage = self.message
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            guard self.session === session else { return }
            if self.isScanning, let nfcError = error as? NFCReaderError,
               nfcError.code == .readerSessionInvalidationErrorSystemIsBusy, self.busyRetryCount < 2 {
                self.session = nil
                self.lease.end()
                self.busyRetryCount += 1
                self.message = "Le lecteur NFC se libère… nouvelle ouverture automatique."
                self.openSession(after: 1.2)
                return
            }
            if self.isScanning {
                self.finish("Lecture interrompue : \(error.localizedDescription). Les réponses sont conservées ; reprenez avec la même carte.")
            }
            self.session = nil
        }
    }

    private func finish(_ status: String) {
        capture?.status = status
        showsFreshRead = capture?.exploration?.finished == true
        message = status
        isScanning = false
        isTagDetected = false
        session = nil
        lease.end()
        save()
        if let capture {
            if capture.transportRegion != .ileDeFrance { RegionalHistory.shared.save(capture, enabled: UserDefaults.standard.bool(forKey: HistoryManager.settingKey)) }
            if capture.exploration?.finished == true {
                UserDefaults.standard.set(capture.transportRegion.rawValue, forKey: TransportRegion.settingKey)
            }
        }
    }

    private func send(_ card: NFCISO7816Tag, cla: UInt8 = 0, instruction: UInt8,
                      p1: UInt8, p2: UInt8, data: Data = Data(), length: Int = 256,
                      name: String) async throws -> Response {
        guard let token = lease.current, isScanning else { throw ObsoleteSession() }
        guard Date() < deadline else { throw Pause() }
        let command = NFCISO7816APDU(instructionClass: cla, instructionCode: instruction,
                                     p1Parameter: p1, p2Parameter: p2, data: data,
                                     expectedResponseLength: length)
        let (bytes, sw1, sw2) = try await card.sendCommand(apdu: command)
        guard lease.accepts(token), isScanning else { throw ObsoleteSession() }
        capture?.exchanges.append(.init(operation: name,
                                       response: bytes.map { String(format: "%02X", $0) }.joined(),
                                       statusWord: String(format: "%02X%02X", sw1, sw2),
                                       application: activeApplication))
        return Response(data: bytes, status: UInt16(sw1) << 8 | UInt16(sw2))
    }

    /// Retry a card-specified response length and follow a bounded GET RESPONSE
    /// chain. Raw replies and status words remain in the report, including refusals.
    private func exchange(_ card: NFCISO7816Tag, instruction: UInt8,
                          p1: UInt8, p2: UInt8, data: Data = Data(), name: String) async throws -> Response {
        var response = try await send(card, instruction: instruction, p1: p1, p2: p2, data: data, name: name)
        var commandClass: UInt8 = 0
        // Legacy Calypso applications may reject ISO class 00. Retry only these
        // read/selection commands, never authentication or a modifying command.
        if response.status == 0x6E00 && [UInt8(0xA4), 0xB0, 0xB2, 0xCA].contains(instruction) {
            commandClass = 0x94
            response = try await send(card, cla: commandClass, instruction: instruction, p1: p1, p2: p2, data: data, name: name + " (classe Calypso)")
        }
        if response.status >> 8 == 0x6C {
            let size = Int(response.status & 255)
            response = try await send(card, cla: commandClass, instruction: instruction, p1: p1, p2: p2,
                                      data: data, length: size == 0 ? 256 : size, name: name + " (Le corrigé)")
        }
        var bytes = response.data
        for _ in 0..<16 where response.status >> 8 == 0x61 {
            let size = Int(response.status & 255)
            response = try await send(card, cla: commandClass, instruction: 0xC0, p1: 0, p2: 0,
                                      length: size == 0 ? 256 : size, name: name + " GET RESPONSE")
            bytes.append(response.data)
        }
        return Response(data: bytes, status: response.status)
    }

    private func selectApplication(_ card: NFCISO7816Tag, aid: String) async throws -> Bool {
        let declared = Bundle.main.object(forInfoDictionaryKey: RegionalApplicationAccess.configurationKey) as? [String] ?? []
        guard RegionalApplicationAccess.permits(aid, declared: declared) else {
            if capture?.exploration?.undeclaredApplications == nil {
                capture?.exploration?.undeclaredApplications = []
            }
            if capture?.exploration?.undeclaredApplications?.contains(aid) != true {
                capture?.exploration?.undeclaredApplications?.append(aid)
            }
            save()
            return false
        }
        var bytes = Data()
        let characters = Array(aid)
        guard !characters.isEmpty, characters.count.isMultiple(of: 2) else { return false }
        for offset in stride(from: 0, to: characters.count, by: 2) {
            guard let byte = UInt8(String(characters[offset...offset + 1]), radix: 16) else { return false }
            bytes.append(byte)
        }
        activeApplication = aid
        return try await exchange(card, instruction: 0xA4, p1: 4, p2: 0,
                                  data: bytes, name: "SELECT \(aid)").status == 0x9000
    }

    private func explore(_ card: NFCISO7816Tag, session: NFCTagReaderSession) async throws {
        try await discoverApplicationOccurrences(card)
        var selected: String?
        var preparedLocation: String?
        while let cursor = capture?.exploration, !cursor.finished {
            let aid = cursor.applications[cursor.application]
            if selected != aid {
                message = "Vérification de l’application \(cursor.application + 1)/\(cursor.applications.count)"
                session.alertMessage = message
                guard try await selectApplication(card, aid: aid) else {
                    capture?.exploration?.nextApplication()
                    save()
                    continue
                }
                selected = aid
                preparedLocation = nil
                if capture?.selectedApplication.isEmpty == true { capture?.selectedApplication = aid }
                if capture?.exploration?.pinStatus == true {
                    if capture?.exploration?.pinStatusRead != true {
                        // Empty data: counter inquiry, never an attempted PIN.
                        _ = try await send(card, cla: RegionalPINStatus.classByte(for: aid), instruction: RegionalPINStatus.instruction, p1: 0, p2: 0,
                                           data: RegionalPINStatus.commandData, name: RegionalPINStatus.operation)
                        capture?.exploration?.pinStatusRead = true
                        save()
                    }
                } else if capture?.exploration?.directoryRead != true {
                    if capture?.exploration?.enumeration == true {
                        try await enumerateDirectory(card, aid: aid)
                    } else {
                        if capture?.exploration?.wideDirectories == true && capture?.exploration?.enumerationCompleted != true {
                            try await enumerateDirectory(card, aid: aid)
                            capture?.exploration?.enumerationCompleted = true
                            save()
                        }
                        try await discoverFiles(card, aid: aid)
                    }
                    capture?.exploration?.directoryRead = true
                    save()
                }
            }
            let locations = capture?.exploration?.locations ?? RegionalScanPlan.locations
            if cursor.location >= locations.count {
                capture?.exploration?.nextApplication(); save(); continue
            }
            let location = locations[cursor.location]
            message = "Application \(cursor.application + 1)/\(cursor.applications.count) · fichier \(cursor.location + 1)/\(locations.count)"
            session.alertMessage = "Lecture approfondie — \(message). Gardez la carte en place."
            if preparedLocation != location.label {
                if let directory = location.directory {
                    guard try await selectApplication(card, aid: aid) else { throw Pause() }
                    let selected = try await exchange(card, instruction: 0xA4, p1: 8, p2: 0,
                        data: Data(directory), name: "SELECT SFI DIRECTORY " + directory.map { String(format: "%02X", $0) }.joined())
                    guard selected.status == 0x9000 else {
                        capture?.exploration?.nextLocation(); save(); continue
                    }
                }
                if let path = location.path {
                    if location.relativeToApplication == true {
                        guard try await selectApplication(card, aid: aid) else { throw Pause() }
                    }
                    let response = try await exchange(card, instruction: 0xA4,
                                                       p1: location.relativeToApplication == true ? 9 : 8, p2: 0,
                                                       data: Data(path), name: "SELECT \(location.label)")
                    guard response.status == 0x9000 else {
                        capture?.exploration?.nextLocation()
                        save()
                        continue
                    }
                }
                preparedLocation = location.label
            }
            if cursor.binary {
                // SFI addressing for the first chunk; later chunks use current EF.
                // On resume, re-establish current EF before continuing at offset.
                let offset = cursor.binaryOffset
                if let sfi = location.sfi, offset > 0 {
                    let first = try await exchange(card, instruction: 0xB0, p1: 0x80 | UInt8(sfi), p2: 0,
                                                   name: "READ BINARY \(location.label) / 0 (sélection)")
                    guard first.status == 0x9000 || first.status == 0x6282 else {
                        capture?.exploration?.nextLocation(); save(); continue
                    }
                }
                let p1 = offset == 0 ? location.sfi.map { 0x80 | UInt8($0) } ?? 0 : UInt8(offset >> 8)
                let result = try await exchange(card, instruction: 0xB0, p1: p1, p2: UInt8(offset & 255),
                                                name: "READ BINARY \(location.label) / \(offset)")
                if result.status == 0x9000 && !result.data.isEmpty && offset + result.data.count < 32768 {
                    capture?.exploration?.binaryOffset += result.data.count
                } else {
                    if result.status == 0x9000 && offset + result.data.count >= 32768 {
                        capture?.exploration?.limitedFiles.append("\(aid) \(location.label): limite 32768 octets")
                    }
                    capture?.exploration?.nextLocation()
                }
            } else {
                let result = try await exchange(card, instruction: 0xB2, p1: UInt8(cursor.record),
                                                p2: location.sfi.map { UInt8(($0 << 3) | 4) } ?? 4,
                                                name: "READ \(location.label) / \(cursor.record)")
                if result.status == 0x9000 || result.status == 0x6282 {
                    if location.path == [0x2F, 0x00] { registerApplications(in: result.data) }
                    if cursor.record < 254 && result.status != 0x6282 {
                        capture?.exploration?.record += 1
                    } else {
                        if cursor.record == 254 { capture?.exploration?.limitedFiles.append("\(aid) \(location.label): limite 254 enregistrements") }
                        capture?.exploration?.nextLocation()
                    }
                } else if cursor.record == 1 && [0x6981, 0x6B00, 0x6A81].contains(result.status) {
                    capture?.exploration?.binary = true
                } else {
                    capture?.exploration?.nextLocation()
                }
            }
            save()
        }
    }

    private func enumerateDirectory(_ card: NFCISO7816Tag, aid: String) async throws {
        // Replay selection only after a pause; no assumption that the card retains
        // its current EF across NFC sessions. Every new descriptor is checkpointed.
        let legacy = aid == "334D54522E494341" || aid == "A0000004040125092001"
        let roots = ["334D54522E494341": "", "A0000004040125092001": "2000",
                     "A0000004040225092001": "1000", "A0000004044125092001": "2300",
                     "A000000291A00000019102": "2100", "A000000291D25008009301": "2200"]
        let known = Set(capture?.regionalFileHeaders.map(\.path) ?? [])
        let replay = capture?.exploration?.enumerationSeen ?? []
        if aid == "334D54522E494341" {
            // EF enumeration covers the current directory, not its child DFs.
            // Always include the public ticketing files below 2000 as well.
            if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
            for location in RegionalScanPlan.quickLocations where !(capture?.exploration?.additionalLocations?.contains(location) ?? false) {
                capture?.exploration?.additionalLocations?.append(location)
            }
        }
        var seen = Set<String>()
        for index in 0..<128 {
            message = "Inventaire direct · application \((capture?.exploration?.application ?? 0) + 1)/\(capture?.exploration?.applications.count ?? 0) · fichier \(index + 1)"
            session?.alertMessage = message
            let result: Response
            if legacy {
                result = try await send(card, cla: 0x94, instruction: 0xA4,
                    p1: 2, p2: index == 0 ? 0 : 2, data: Data([0, 0]), name: "ENUMERATE EF \(index + 1)")
            } else {
                result = try await exchange(card, instruction: 0xA4,
                    p1: 2, p2: index == 0 ? 0 : 2, data: Data([0, 0]), name: "ENUMERATE EF \(index + 1)")
            }
            guard result.status == 0x9000 else {
                if index == 0 {
                    // Some earlier cards do not offer sequential enumeration.
                    // Still attempt the public ticketing paths; no PIN is sent.
                    let ordinary = RegionalScanPlan.quickLocations
                    let rootSFIs = (1...30).map { RegionalScanPlan.Location(sfi: $0, path: nil) }
                    let relative = ordinary.map { RegionalScanPlan.Location(sfi: nil, path: Array(($0.path ?? []).suffix(2)), relativeToApplication: true) }
                    for location in rootSFIs + relative + ordinary where !(capture?.exploration?.additionalLocations?.contains(location) ?? false) {
                        if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
                        capture?.exploration?.additionalLocations?.append(location)
                    }
                }
                if result.status != 0x6A82 && result.status != 0x6A83 {
                    capture?.exploration?.limitedFiles.append(String(format: "%@: inventaire interrompu (%04X)", aid, result.status))
                }
                return
            }
            let hex = result.data.map { String(format: "%02X", $0) }.joined()
            guard RegionalFileHeader.decode(hex, path: "") != nil else {
                capture?.exploration?.limitedFiles.append("\(aid): réponse d’inventaire non reconnue")
                return
            }
            guard seen.insert(hex).inserted else {
                capture?.exploration?.limitedFiles.append("\(aid): inventaire cyclique, arrêt après répétition")
                return
            }
            if index < replay.count {
                guard replay[index] == hex else {
                    capture?.exploration?.limitedFiles.append("\(aid): inventaire modifié pendant la reprise")
                    return
                }
                continue
            }
            let info = Array(result.data.dropFirst(2))
            guard let lid = RegionalFileHeader.logicalIdentifier(hex, legacy: legacy) else { return }
            let root = roots[aid] ?? ""
            if lid != 0 && lid != 0xFFFF {
                let path = root + String(format: "%04X", lid)
                if !known.contains(path) {
                    let location = RegionalScanPlan.Location(sfi: nil, path: [UInt8(lid >> 8), UInt8(lid & 255)], relativeToApplication: true)
                    if !(capture?.exploration?.locations.contains(location) ?? false) {
                        if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
                        capture?.exploration?.additionalLocations?.append(location)
                    }
                }
            } else if (1...30).contains(Int(info[0])) {
                // Missing LID: scoped SFI is still readable, without inventing a path.
                let directory: [UInt8] = root.isEmpty ? [] : [UInt8(Int(root, radix: 16)! >> 8), 0]
                let location = RegionalScanPlan.Location(sfi: Int(info[0]), path: nil, directory: directory.isEmpty ? nil : directory)
                if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
                capture?.exploration?.additionalLocations?.append(location)
            } else {
                capture?.exploration?.limitedFiles.append("\(aid): fichier sans adresse exploitable")
            }
            // A new application's FID layout can differ from the known legacy
            // aliases. Its advertised root SFI is an independent addressing path.
            if roots[aid] == nil, (1...30).contains(Int(info[0])) {
                let scoped = RegionalScanPlan.Location(sfi: Int(info[0]), path: nil)
                if !(capture?.exploration?.locations.contains(scoped) ?? false) {
                    if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
                    capture?.exploration?.additionalLocations?.append(scoped)
                }
            }
            if capture?.exploration?.enumerationSeen == nil { capture?.exploration?.enumerationSeen = [] }
            capture?.exploration?.enumerationSeen?.append(hex)
            save()
        }
        capture?.exploration?.limitedFiles.append("\(aid): limite d’inventaire de 128 fichiers")
    }

    private func registerApplications(in data: Data) {
        guard let aids = RegionalApplicationDirectory.identifiers(data) else { return }
        for aid in aids {
            guard let cursor = capture?.exploration, cursor.applications.count < 16 else { return }
            if !cursor.applications.contains(aid) { capture?.exploration?.applications.append(aid) }
        }
    }

    private func discoverFiles(_ card: NFCISO7816Tag, aid: String) async throws {
        // Directory access is optional. An unsupported GET DATA is logged and
        // the ordinary read plan remains available. Re-select before each context.
        let contexts = capture?.exploration?.contexts ?? RegionalScanPlan.directoryContexts(for: aid)
        while (capture?.exploration?.directoryIndex ?? 0) < contexts.count {
            let index = capture?.exploration?.directoryIndex ?? 0
            let context = contexts[index]
            message = "Recherche de dossiers \(index + 1)/\(contexts.count)"
            session?.alertMessage = "\(message) — gardez la carte en place."
            guard try await selectApplication(card, aid: aid) else { throw Pause() }
            let name = context.isEmpty ? "APP" : context.map { String(format: "%02X", $0) }.joined()
            if !context.isEmpty {
                let selected = try await exchange(card, instruction: 0xA4, p1: 8, p2: 0,
                                                   data: Data(context), name: "SELECT DIRECTORY \(name)")
                guard selected.status == 0x9000 else {
                    capture?.exploration?.directoryIndex = index + 1
                    save()
                    continue
                }
            }
            if capture?.exploration?.wideDirectories == true && !context.isEmpty {
                // Only scan the SFIs of a directory after selection succeeded.
                for sfi in 1...30 {
                    let location = RegionalScanPlan.Location(sfi: sfi, path: nil, directory: context)
                    if !(capture?.exploration?.additionalLocations?.contains(location) ?? false) {
                        if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
                        capture?.exploration?.additionalLocations?.append(location)
                    }
                }
            }
            if capture?.exploration?.supplementary == true {
                // Checkpoint each metadata request so interruption does not loop
                // indefinitely on a slow or unsupported command.
                while (capture?.exploration?.metadataIndex ?? 0) < 3 {
                    let step = capture?.exploration?.metadataIndex ?? 0
                    let result: Response
                    if step == 2 {
                        result = try await exchange(card, instruction: 0xCB, p1: 0x2F, p2: 0,
                            data: Data([0x5C, 0]), name: "GET DATA ISO APPLICATION DIRECTORY \(name)")
                    } else {
                        result = try await exchange(card, instruction: 0xCA, p1: 0, p2: step == 0 ? 0xD0 : 0x4F,
                            name: "GET DATA \(step == 0 ? "LINKED APPLICATIONS" : "CURRENT AID") \(name)")
                    }
                    if result.status == 0x9000 { registerApplications(in: result.data) }
                    capture?.exploration?.metadataIndex = step + 1
                    save()
                }
            }
            let result = try await exchange(card, instruction: 0xCA, p1: 0, p2: 0xC0,
                                             name: "GET DATA EF LIST \(name)")
            let files = result.status == 0x9000 ? RegionalFileDirectory.fileIDs(result.data) ?? [] : []
            for id in files {
                let path = context + [UInt8(id >> 8), UInt8(id & 255)]
                let location = RegionalScanPlan.Location(sfi: nil, path: path, relativeToApplication: context.isEmpty)
                let existing = capture?.exploration?.locations ?? []
                if !existing.contains(where: { $0.label == location.label }) {
                    if capture?.exploration?.additionalLocations == nil { capture?.exploration?.additionalLocations = [] }
                    capture?.exploration?.additionalLocations?.append(location)
                }
            }
            capture?.exploration?.directoryIndex = index + 1
            capture?.exploration?.metadataIndex = 0
            save()
        }
        // Restore the application before the first SFI read.
        guard try await selectApplication(card, aid: aid) else { throw Pause() }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "Présentez une seule carte."
            session.restartPolling()
            return
        }
        guard case .iso7816(let card) = tag else {
            finish("Technologie non prise en charge par ce lecteur expérimental.")
            session.invalidate(errorMessage: message)
            return
        }
        DispatchQueue.main.async {
            guard self.session === session, self.isScanning else { return }
            self.isTagDetected = true
        }
        session.connect(to: tag) { error in
            Task { @MainActor in
                guard self.session === session else { return }
                do {
                    if let error { throw error }
                    self.deadline = Date().addingTimeInterval(40)
                    let identifier = card.identifier.map { String(format: "%02X", $0) }.joined()
                    if let expected = self.expectedCardIdentifier, expected.uppercased() != identifier {
                        self.finish("Carte différente : présentez la carte ouverte dans l’historique. Sa lecture enregistrée est conservée.")
                        session.invalidate(errorMessage: "Présentez la carte ouverte dans l’historique.")
                        return
                    }
                    if self.resumeRequested {
                        guard self.capture?.exploration?.cardIdentifier == identifier else {
                            self.message = "La carte présentée diffère de celle du rapport. Reprenez avec la même carte ou démarrez une nouvelle lecture."
                            self.isScanning = false
                            self.session = nil
                            self.lease.end()
                            session.invalidate(errorMessage: "Carte différente. Le rapport précédent est conservé.")
                            return
                        }
                    } else {
                        var seen = Set<String>()
                        let applications = ["334D54522E494341", card.initialSelectedAID, "A0000004040125092001", "315449432E494341"]
                            .map { $0.uppercased() }.filter { !$0.isEmpty && seen.insert($0).inserted }
                        let region = RegionalCardProfiles.confirmed[identifier] ?? (card.initialSelectedAID.uppercased().hasPrefix("315449432E494341D056") ? .mobib : self.capture?.declaredRegion ?? .sud)
                        let plan = self.researchRequested ? RegionalScanPlan.inventoryApplications(initialAID: card.initialSelectedAID) : self.inventoryRequested ? RegionalScanPlan.inventoryApplications(initialAID: card.initialSelectedAID) : self.quickRequested ? RegionalScanPlan.quickApplications(region: region, initialAID: card.initialSelectedAID) : applications
                        var cursor = RegionalScanPlan.Cursor(applications: plan, cardIdentifier: identifier)
                        cursor.region = region
                        self.capture?.declaredRegion = region
                        if self.researchRequested { cursor.supplementary = true; cursor.wideDirectories = true }
                        if self.inventoryRequested { cursor.enumeration = true }
                        if self.quickRequested {
                            cursor.quick = true
                            cursor.directoryRead = true
                        }
                        self.capture?.exploration = cursor
                    }
                    // Native discovery data only: no additional card command,
                    // no authentication and no change to the scan plan.
                    self.capture?.nfcMetadata = .init(identifier: identifier,
                        initialSelectedAID: card.initialSelectedAID,
                        historicalBytes: card.historicalBytes.map { $0.map { String(format: "%02X", $0) }.joined() },
                        applicationData: card.applicationData.map { $0.map { String(format: "%02X", $0) }.joined() },
                        proprietaryApplicationDataCoding: card.proprietaryApplicationDataCoding)
                    self.save()
                    if self.capture?.exploration?.supportOnly == true {
                        self.capture?.exploration?.nextApplication()
                        self.finish("Interface NFC identifiée. Les fichiers déjà lus sont conservés ; aucune commande de lecture supplémentaire n’a été envoyée.")
                        session.alertMessage = "Identification du support terminée."
                        session.invalidate()
                        return
                    }
                    try await self.explore(card, session: session)
                    let titles = (self.capture?.regionalContracts.count ?? 0) + (self.capture?.mobibTitles.count ?? 0)
                    let partialTitles = self.capture?.regionalUninterpretedTitles.count ?? 0
                    let events = self.capture?.decodedJourneyCount ?? 0
                    var summary = self.capture?.applicationSummary ?? ""
                    let families = self.capture?.applicationFamilyResults ?? []
                    if !families.isEmpty {
                        summary += " · \(families.filter(\.ended).count)/\(families.count) fins de liste confirmées pour les familles interrogées"
                    }
                    session.alertMessage = "Recherche terminée. Consultez le bilan des applications dans la fiche."
                    self.finish("Recherche terminée · \(titles) titres interprétés, \(partialTitles) titres partiellement décodés et \(events) événements décodés. \(summary). Cela ne garantit pas une copie complète de la carte.")
                    session.invalidate()
                } catch is ObsoleteSession {
                    return
                } catch is Pause {
                    guard self.session === session else { return }
                    self.finish("Lecture en pause. Le rapport est sauvegardé ; touchez Reprendre et présentez la même carte.")
                    session.invalidate()
                } catch {
                    guard self.session === session else { return }
                    self.finish("Lecture interrompue : \(error.localizedDescription). Le rapport est sauvegardé ; reprenez avec la même carte.")
                    session.invalidate(errorMessage: "Lecture interrompue. Le rapport est conservé.")
                }
            }
        }
    }
}

#endif
