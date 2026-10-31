#if os(iOS)
import SwiftUI

struct RegionalCardView: View {
    @ObservedObject private var reader = RegionalCardReader.shared
    var archivedCapture: RegionalCardCapture? = nil
    var region: TransportRegion = .sud
    var researchOnly = false
    @ObservedObject private var regionalHistory = RegionalHistory.shared
    @State private var startedArchiveRead = false
    @State private var showsRename = false
    @State private var showsArtwork = false
    @State private var nickname = ""
    private var savedRecord: RegionalHistoryRecord? {
        guard let uid = displayedCapture?.exploration?.cardIdentifier else { return nil }
        return regionalHistory.records.first { $0.capture.exploration?.cardIdentifier == uid }
    }

    private var displayedCapture: RegionalCardCapture? {
        if let archivedCapture {
            if startedArchiveRead, let fresh = reader.capture,
               fresh.exploration?.cardIdentifier == archivedCapture.exploration?.cardIdentifier,
               fresh.exploration?.finished == true { return enriched(fresh) }
            return archivedCapture
        }
        guard reader.showsFreshRead, let capture = reader.capture,
              capture.transportRegion == region else { return nil }
        return enriched(capture)
    }
    private func enriched(_ capture: RegionalCardCapture) -> RegionalCardCapture {
        if let saved = regionalHistory.records.first(where: { $0.capture.exploration?.cardIdentifier == capture.exploration?.cardIdentifier }),
           saved.lastReadDate == capture.date { return saved.capture }
        return capture
    }
    private var displayRegion: TransportRegion { displayedCapture?.transportRegion ?? region }
    private var reading: Bool { (archivedCapture == nil || startedArchiveRead) && reader.isScanning }
    private func beginRead(inventory: Bool = false, resuming: Bool = false) {
        UserDefaults.standard.set(displayRegion.rawValue, forKey: TransportRegion.settingKey)
        startedArchiveRead = archivedCapture != nil
        reader.start(resuming: resuming, quick: !inventory && !(researchOnly && displayedCapture == nil), inventory: inventory, research: researchOnly && displayedCapture == nil,
                     expectedCardIdentifier: archivedCapture?.exploration?.cardIdentifier)
    }
    private func beginResearch() {
        UserDefaults.standard.set(displayRegion.rawValue, forKey: TransportRegion.settingKey)
        startedArchiveRead = archivedCapture != nil
        if let capture = displayedCapture { reader.deepen(from: capture) }
        else { reader.start(research: true) }
    }
    private func readNewApplications() {
        guard let capture = displayedCapture else { return }
        UserDefaults.standard.set(displayRegion.rawValue, forKey: TransportRegion.settingKey)
        startedArchiveRead = archivedCapture != nil
        reader.readNewApplications(from: capture)
    }
    private func newlySelectable(_ capture: RegionalCardCapture) -> [String] {
        capture.newlySelectableApplications(declared: Bundle.main.object(forInfoDictionaryKey: RegionalApplicationAccess.configurationKey) as? [String] ?? [])
    }
    private func beginApplicationEnumeration() {
        guard let capture = displayedCapture else { return }
        UserDefaults.standard.set(displayRegion.rawValue, forKey: TransportRegion.settingKey)
        startedArchiveRead = archivedCapture != nil
        reader.enumerateApplicationFamilies(from: capture)
    }
    private var canResumeDisplayed: Bool {
        reader.canResume && reader.capture?.exploration?.cardIdentifier == displayedCapture?.exploration?.cardIdentifier
    }
    private var primaryReadTitle: String {
        if canResumeDisplayed { return "Reprendre la lecture interrompue" }
        if let capture = displayedCapture, !newlySelectable(capture).isEmpty {
            return "Lire les nouvelles applications (\(newlySelectable(capture).count))"
        }
        return "Actualiser les titres et passages"
    }
    private func primaryReadAction() {
        if canResumeDisplayed { beginRead(resuming: true) }
        else if let capture = displayedCapture, !newlySelectable(capture).isEmpty { readNewApplications() }
        else { beginRead() }
    }
    private var readActions: some View {
        Section {
            Button { primaryReadAction() } label: {
                Label(primaryReadTitle, systemImage: canResumeDisplayed ? "arrow.clockwise" : "wave.3.forward")
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.disabled(reader.isScanning)
            Menu {
                Button("Vérifier la liste des applications", systemImage: "list.bullet.rectangle") { beginApplicationEnumeration() }
                Button("Inventorier les fichiers accessibles", systemImage: "doc.text.magnifyingglass") { beginRead(inventory: true) }
                Button("Recherche élargie de dossiers et fichiers", systemImage: "magnifyingglass") { beginResearch() }
                if canResumeDisplayed { Button("Démarrer une nouvelle lecture", systemImage: "wave.3.forward") { beginRead() } }
            } label: { Label("Options de lecture", systemImage: "ellipsis.circle") }
            .disabled(reader.isScanning)
            if canResumeDisplayed {
                Text("La recherche est sauvegardée. Présente la même carte pour continuer.").font(.footnote).foregroundStyle(.secondary)
            }
            if startedArchiveRead {
                DisclosureGroup("Dernier compte rendu") { Text(reader.message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var transportFilter = 0
    @State private var showsDiagnostic = false

    @AppStorage("regionalCodeLabels.v1") private var codeLabelsJSON = "{}"
    @State private var editingCode: CodeEdit?
    @State private var editedName = ""
    @State private var showsNameEditor = false

    private struct CodeEdit {
        let network: Int
        let field: String
        let code: Int
        let title: String
    }

    private var events: [RegionalEvent] {
        (displayedCapture?.regionalEvents ?? []).filter {
            transportFilter == 0 || (transportFilter == 1 ? $0.mode == 5 : transportFilter == 3 ? $0.mode == 4 : transportFilter == 4 ? $0.mode == 3 : [1, 2].contains($0.mode))
        }
    }

    var body: some View {
        Group {
            if (archivedCapture == nil && displayedCapture == nil) || reading {
                EmptyScanView(isScanning: reading, isTagDetected: reader.isTagDetected, onScan: { beginRead() }, onImport: {}, networkName: region.network, fixedExample: region.cardAsset, allowsImport: false)
                    .overlay(alignment: .bottom) {
                        if !reading {
                            VStack {
                                if reader.canResume {
                                    Button("Reprendre la lecture interrompue") { beginRead(resuming: true) }
                                }
                            }.font(.footnote).padding(.bottom, 16)
                        }
                    }
            } else { cardContent }
        }
        .navigationTitle(savedRecord?.displayTitle ?? "Ma carte \(displayRegion.network)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let record = savedRecord {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Renommer la carte", systemImage: "pencil") { nickname = record.nickname ?? ""; showsRename = true }
                        Button("Changer l’image", systemImage: "photo") { showsArtwork = true }
                    } label: { Image(systemName: "square.and.pencil") }
                }
            }
        }
        .alert("Renommer la carte", isPresented: $showsRename) {
            TextField("Nom de la carte", text: $nickname)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") { if let record = savedRecord { regionalHistory.personalize(record.id, nickname: nickname) } }
        }
        .sheet(isPresented: $showsArtwork) {
            RegionalArtworkPicker { image in if let record = savedRecord { regionalHistory.personalize(record.id, imageName: image) } }
        }
        .sheet(isPresented: $showsDiagnostic) { diagnostic }
        .onDisappear { if archivedCapture == nil || startedArchiveRead { reader.stop() } }
    }

    private var cardContent: some View {
        List {
                Section {
                    RegionalCardArtwork(region: displayRegion, imageName: savedRecord?.imageName)
                        .frame(maxWidth: 440)
                        .frame(maxWidth: .infinity)
                        .onTapGesture(count: 2) { if savedRecord != nil { showsArtwork = true } }
                        .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                readActions

                if let capture = displayedCapture, !reading {
                    if capture.usesEarlierTicketingReads || capture.usesEarlierMobibReads {
                        Section {
                            Text("Certains fichiers n’ont pas été relus pendant ce complément. Leurs dernières données connues sont conservées ; les lectures datées restent disponibles dans les outils.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if displayRegion != .sud && (capture.regionalAMC != nil || capture.regionalEnvironment != nil || capture.hasMobibLayout) {
                        Section("Informations du support") {
                            LabeledContent("Réseau", value: displayRegion.network)
                            if let environment = capture.regionalEnvironment {
                                LabeledContent("Type de carte", value: environment.personalizationLabel)
                                LabeledContent("Échéance technique", value: environment.expiryLabel)
                                Text("Cette date concerne l’application de billetterie du support, pas un abonnement.").font(.footnote).foregroundStyle(.secondary)
                                DisclosureGroup("Profil enregistré sur la carte") {
                                    LabeledContent("Format", value: environment.versionLabel)
                                    LabeledContent("Code réseau", value: String(format: "%06X", environment.network))
                                    LabeledContent("Code émetteur", value: String(environment.issuer))
                                    if let commercial = environment.commercialCode {
                                        LabeledContent("Code commercial", value: String(commercial))
                                        Text("L’intitulé de ce code reste à identifier ; il n’est pas présenté comme un titre chargé.").font(.footnote).foregroundStyle(.secondary)
                                    }
                                    if let birth = environment.birthDate { LabeledContent("Date de naissance enregistrée", value: birth).privacySensitive() }
                                }
                            }
                            if let expiry = capture.mobibTechnicalExpiryDay {
                                LabeledContent("Échéance technique", value: RegionalContract.dateLabel(expiry))
                                Text("Cette date concerne l’application du support MOBIB, pas la durée de validité de chaque voyage.").font(.footnote).foregroundStyle(.secondary)
                            }
                            if let amc = capture.regionalAMC {
                                LabeledContent("Date des données multiservices", value: amc.encodedDate)
                                Text("Le support contient \(amc.sectors.count) identifiants de services. Ce nombre ne représente pas des voyages ni des titres chargés.").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("Titres et droits") {
                        ForEach(capture.mobibTitles) { title in
                            VStack(alignment: .leading, spacing: 8) {
                                Label(title.name ?? "Titre MOBIB · code \(title.tariff)", systemImage: "ticket.fill").font(.headline)
                                if let count = title.remainingJourneys { Text("\(count) voyages restants selon le compteur de la carte").font(.title3) }
                                Text("Montant encodé du titre : " + (Double(title.priceCents) / 100).formatted(.currency(code: "EUR")))
                                if let sale = title.saleDay { Text("Vente encodée : " + RegionalContract.dateLabel(sale)) }
                                DisclosureGroup("Détails du titre") {
                                    LabeledContent("Code produit", value: String(title.tariff))
                                    LabeledContent("Emplacement", value: String(title.id))
                                    Text("Décodage partiel du format MOBIB ; les autres champs restent conservés dans la lecture brute.").font(.footnote).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6)
                        }
                        if capture.regionalContracts.isEmpty && capture.regionalUninterpretedTitles.isEmpty && capture.mobibTitles.isEmpty {
                            Text(capture.hasFileRead ? "Aucun titre décodé dans cette lecture." : "Lecture des fichiers à effectuer avec cette version.").foregroundStyle(.secondary)
                        }
                        ForEach(capture.regionalContracts) { contract in
                            contractRow(contract, capture: capture)
                        }
                        ForEach(capture.regionalUninterpretedTitles) { title in
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Titre · code \(title.tariff)", systemImage: "ticket.fill").font(.headline)
                                Text("Structure \(title.structure) · emplacement \(title.id)").font(.caption).foregroundStyle(.secondary)
                                if let status = title.status {
                                    Text(status == 1 ? "Statut encodé : utilisé" : status == 13 ? "Statut encodé : non validable" : "Statut encodé : \(status)")
                                }
                                Text("Émetteur du titre : code \(title.provider)").font(.subheadline)
                                if let start = title.startDay { LabeledContent("Début encodé", value: RegionalContract.dateLabel(start)) }
                                if let end = title.endDay { LabeledContent("Fin de validité encodée", value: RegionalContract.dateLabel(end)) }
                                if let sale = title.saleDay { LabeledContent("Date de vente encodée", value: RegionalContract.dateLabel(sale)) }
                                if title.decodedBitCount > 0 {
                                    DisclosureGroup("Détails encodés du titre") {
                                        if let device = title.saleDevice { LabeledContent("Terminal de vente", value: String(device)) }
                                        if let agent = title.saleAgent { LabeledContent("Agent de vente · code", value: String(agent)) }
                                        if let passenger = title.passengerClass { LabeledContent("Classe voyageur · code", value: String(passenger)) }
                                        if let zones = title.zones { LabeledContent("Masque de zones", value: String(format: "0x%04X", zones)) }
                                        if let stored = title.storedValue { LabeledContent("Valeur chargée · brute", value: String(stored)) }
                                        if let debit = title.debit { LabeledContent("Débit unitaire · brut", value: String(debit)) }
                                        if let counter = capture.partialTitleCounter(title.id) { LabeledContent("Compteur associé · brut", value: String(counter)) }
                                        if title.storedValue != nil { Text("L’unité de ces valeurs reste inconnue : elles ne représentent pas un nombre de voyages établi.").font(.footnote).foregroundStyle(.secondary) }
                                        if title.encodedPrice == 0 { Text("Le champ prix vaut zéro ; cela ne prouve pas que le titre était gratuit.").font(.footnote).foregroundStyle(.secondary) }
                                    }
                                }
                                Text(title.endDay == nil ? "Le nom commercial, la validité et le solde de ce format restent à décoder." : "Le nom commercial reste à identifier. Aucune date de début n’est ajoutée si elle est absente de la carte.").font(.footnote).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }
                    }
                    Section {
                        Picker("Transport", selection: $transportFilter) {
                            Text("Tous").tag(0)
                            Text("Train").tag(1)
                            Text("Bus / car").tag(2)
                            Text("Tram").tag(3)
                            Text("Métro").tag(4)
                        }.pickerStyle(.segmented)
                        let mobibEvents = capture.mobibEvents.filter {
                            transportFilter == 0 || (transportFilter == 2 && $0.mode == 15) || (transportFilter == 3 && [6,22].contains($0.mode)) || (transportFilter == 4 && [0,7].contains($0.mode))
                        }
                        ForEach(mobibEvents) { event in
                            VStack(alignment: .leading, spacing: 8) {
                                Label(event.modeLabel + (event.route.map { " · ligne \($0)" } ?? ""), systemImage: event.mode == 15 ? "bus" : "tram").font(.headline)
                                if let name = event.placeName { Text(name + " · à confirmer").font(.title3.weight(.medium)) }
                                Text(event.header.label).foregroundStyle(.secondary)
                                DisclosureGroup("Détails du passage") {
                                    LabeledContent("Code de lieu", value: String(event.location))
                                    if let stop = event.busLocation { LabeledContent("Code arrêt bus", value: String(stop)) }
                                    if let sequence = event.sequence { LabeledContent("Numéro de transaction encodé", value: String(sequence)) }
                                    if let first = event.firstStamp { LabeledContent("Première validation encodée", value: first.label) }
                                    LabeledContent("Fichier source", value: event.sourceFile)
                                    Text(event.placeName == nil ? "Le nom de l’arrêt reste à identifier ; ce fichier ne constitue pas un historique exhaustif." : "Correspondance d’un ancien référentiel MOBIB : Trinité, à Ixelles. L’arrêt exact de validation reste à confirmer.").font(.footnote).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6)
                        }
                        if events.isEmpty && mobibEvents.isEmpty {
                            Label(!capture.hasFileRead ? "Les fichiers d’événements restent à lire." : transportFilter == 2 ? "Aucune validation de bus décodée dans cette lecture." : "Aucun événement décodé pour ce filtre.", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(events) { event in
                            eventRow(event, capture: capture)
                        }
                        if transportFilter == 2 && displayRegion == .sud {
                            DisclosureGroup("Pourquoi un trajet bus peut manquer ?") {
                                Text("Matawan décrit la Région Sud comme un réseau hybride : certaines informations sont sur la carte, d’autres dans un compte central. Un scan NFC ne garantit donc pas un historique de tous les trajets. Le fonctionnement précis de tes validations sur la ligne 59 n’est pas encore établi.")
                                    .font(.footnote).foregroundStyle(.secondary)
                                Link("Explication du fournisseur Matawan", destination: URL(string: "https://matawan-mobility.com/blog/interoperabilite-ou-en-est-on-ou-allons-nous/")!)
                            }
                        }
                    } header: { Text("Mes passages") }
                    footer: {
                        Text("Les dates sont celles enregistrées par la carte. Un événement enregistré ne prouve pas, à lui seul, qu’une validation a été acceptée.")
                    }

                    if !capture.regionalSpecialEvents.isEmpty {
                        Section("Autres événements enregistrés") {
                            ForEach(capture.regionalSpecialEvents) { event in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(event.header.label).font(.headline)
                                    if let location = event.location {
                                        let name = event.provider == 2
                                            ? RegionalStationNames.name(code: location, network: capture.ticketingNetworkID) : nil
                                        Text(name.map { "\($0) · code \(location)" } ?? "Code de lieu : \(location)")
                                    }
                                    DisclosureGroup("Données de l’événement") {
                                        if let result = event.result { LabeledContent("Code résultat à interpréter", value: String(result)) }
                                        if let provider = event.provider { LabeledContent("Code transporteur", value: String(provider)) }
                                        if let contract = event.contract { LabeledContent("Titre référencé · emplacement", value: String(contract)) }
                                        if let device = event.device { LabeledContent("Code équipement", value: String(device)) }
                                        Text(event.hasRecordedCode ? "Code événement : \(event.code)" : "Le type d’événement et le mode de transport ne sont pas renseignés.")
                                            .font(.footnote).foregroundStyle(.secondary)
                                        Text("Ce fichier est distinct du journal des passages. Le code résultat ne suffit pas à qualifier cet événement de validation ou de refus.")
                                            .font(.footnote).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 6)
                            }
                        }
                    }

                }
                if let capture = displayedCapture, !capture.applicationAttempts.isEmpty || !capture.applicationFamilyResults.isEmpty {
                    Section {
                        DisclosureGroup("État et limites de la lecture") {
                            if !capture.enumeratedReadCoverage.isEmpty {
                                let files = capture.enumeratedReadCoverage
                                LabeledContent("Fichiers entièrement lus", value: "\(files.filter(\.complete).count) / \(files.count)")
                                LabeledContent("Fichiers avec accès refusé", value: String(files.filter(\.refused).count))
                                Text("Ce bilan porte sur les fichiers annoncés par l’inventaire de cette lecture. Il ne prouve pas l’absence d’autres fichiers ou applications.").font(.footnote).foregroundStyle(.secondary)
                            }
                            if !capture.applicationAttempts.isEmpty {
                                Text(capture.applicationSummary).font(.subheadline)
                                Text("Les identifiants vérifiés ne sont pas tous nécessairement présents ou lisibles.").font(.footnote).foregroundStyle(.secondary)
                                ForEach(capture.applicationAttempts) { attempt in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(attempt.label).font(.caption)
                                        Text(attempt.id).font(.caption2.monospaced()).textSelection(.enabled)
                                    }
                                }
                            }
                            ForEach(capture.applicationFamilyResults) { family in
                                LabeledContent(family.id, value: family.label).font(.caption)
                            }
                            if !capture.applicationFamilyResults.isEmpty {
                                Text("Une fin de liste n’est confirmée que pour la famille interrogée. Une famille non prise en charge ou inconnue empêche de garantir un inventaire universel.").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button { showsDiagnostic = true } label: {
                        Label("Informations et outils développeur", systemImage: "slider.horizontal.3")
                    }
                }

            }
            .modifier(TransportReadableList())
            .buttonStyle(.borderless)
            .navigationTitle(savedRecord?.displayTitle ?? "Ma carte \(displayRegion.network)")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Nommer ce code", isPresented: $showsNameEditor) {
                TextField("Nom à afficher", text: $editedName)
                Button("Enregistrer") {
                    if let edit = editingCode {
                        var labels = RegionalCodeLabels(json: codeLabelsJSON)
                        labels.set(editedName, network: edit.network, field: edit.field, code: edit.code)
                        codeLabelsJSON = labels.json
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("\(editingCode?.title ?? "Code") · \(editingCode?.code ?? 0). Le nom sera une annotation locale, distincte des données lues. Effacer le nom retire l’annotation.")
            }
    }

    @ViewBuilder
    private func namedCode(_ title: String, field: String, code: Int, capture: RegionalCardCapture) -> some View {
        if let network = capture.ticketingNetworkID {
            let name = RegionalCodeLabels(json: codeLabelsJSON).label(network: network, field: field, code: code)
            Button {
                editingCode = .init(network: network, field: field, code: code, title: title)
                editedName = name ?? ""
                showsNameEditor = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).foregroundStyle(.primary)
                        Text(name.map { "\($0) · nom ajouté par toi" } ?? "Code \(code) · nom à identifier")
                            .font(.footnote).foregroundStyle(.secondary)
                        if name != nil { Text("Code lu : \(code)").font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Image(systemName: "pencil").foregroundStyle(.secondary)
                }
            }.buttonStyle(.borderless)
        } else {
            LabeledContent(title, value: String(code))
        }
    }

    private func contractRow(_ contract: RegionalContract, capture: RegionalCardCapture) -> some View {
        let usage = capture.regionalEvents.filter { $0.contract == contract.id }
        let customTitle = capture.ticketingNetworkID.flatMap { RegionalCodeLabels(json: codeLabelsJSON).label(network: $0, field: "tariff:\(contract.provider):\(contract.structure)", code: contract.tariff) }
        return VStack(alignment: .leading, spacing: 8) {
            Label(customTitle ?? (capture.regionalPreferredJourneyHint?.contractID == contract.id ? "Trajet de référence probable" : (capture.regionalPreferredJourneyHint != nil && contract.id == 5 ? "Pass ZOU! Études · déclaré" : (usage.isEmpty ? "Droit de transport complémentaire" : "Titre de transport utilisé"))), systemImage: "ticket.fill")
                .font(.headline)
            Text(contract.validity)
            if let amount = contract.priceCents {
                Text("Prix de l’abonnement : " + (Double(amount) / 100).formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_FR"))))
                    .font(.subheadline)
            }
            if let hint = capture.regionalPreferredJourneyHint, hint.contractID == contract.id {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Marseille–Saint-Charles → Toulon").font(.subheadline.bold())
                    Text("Trajet déclaré lors de l’inscription").font(.subheadline)
                    Text("Ligne indiquée par le porteur : \(hint.declaredLine)").font(.footnote)
                    DisclosureGroup("À propos de ce trajet") {
                        Text("Le trajet et les données de vente concordent avec les informations données lors de l’inscription. Le rôle de ce droit reste une interprétation probable.").font(.footnote).foregroundStyle(.secondary)
                        Link("Rôle du trajet de référence · ZOU!", destination: URL(string: "https://zou.maregionsud.fr/pass-zou-etudes-billet-train-0-euros")!).font(.footnote)
                    }

                }
            }
            if contract.status == 13 {
                Text(capture.regionalPreferredJourneyHint?.contractID == contract.id ? "Ce droit semble accompagner l’abonnement pour indiquer ton trajet habituel. Aucun prix supplémentaire n’a été décodé pour ce droit." : "Ce droit ne sert pas directement à valider selon le référentiel. Son rôle reste à identifier.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !usage.isEmpty { Text("\(usage.count) passages lus avec cet abonnement").font(.subheadline).foregroundStyle(.secondary) }
            DisclosureGroup("Informations du titre") {
                LabeledContent("Emplacement technique", value: String(contract.id))
                LabeledContent("Statut", value: contract.statusLabel)
                if let priority = contract.priority { LabeledContent("Priorité encodée", value: String(priority)) }
                namedCode("Fournisseur du titre", field: "contractProvider", code: contract.provider, capture: capture)
                Text("Ce code est propre au réseau de billetterie. Il ne permet pas, à lui seul, de nommer l’entreprise qui exploite le bus ou le train.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let serial = contract.serialNumber { LabeledContent("Numéro de série du titre", value: String(serial)) }
                if let passengerClass = contract.passengerClass { LabeledContent("Classe encodée", value: String(passengerClass)) }
                if let saleDay = contract.saleDay { LabeledContent("Date de vente encodée", value: RegionalEnvironment.dayLabel(saleDay)) }
                if let agent = contract.saleAgent { LabeledContent("Code agent de vente", value: String(agent)) }
                if let device = contract.saleDevice {
                    LabeledContent("Code équipement de vente", value: String(device))
                    Text("Pour une carte reçue déjà chargée, ce champ peut désigner un équipement de préparation. Il n’identifie pas une borne de validation utilisée pendant un trajet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let method = contract.paymentMethod { LabeledContent("Code moyen de paiement", value: String(method)) }
                if let zones = contract.zones { LabeledContent("Masque de zones", value: String(format: "%04X", zones)) }
                if let receipt = contract.receiptDelivered { LabeledContent("Justificatif de vente encodé", value: receipt ? "Oui" : "Non") }
                if let vehicle = contract.vehicleCode { LabeledContent("Code de mode autorisé", value: vehicle == 0 ? "Non précisé · 0" : String(vehicle)) }
                if let linked = contract.linkedContract { LabeledContent("Référence de droit lié", value: String(linked)) }
                Text(contract.hasUndecodedNonzeroBits ? "Des données complémentaires restent à interpréter dans ce format." : "Les champs reconnus couvrent toutes les données non nulles de cet enregistrement.")
                    .font(.footnote).foregroundStyle(.secondary)
                namedCode("Nom du tarif", field: "tariff:\(contract.provider):\(contract.structure)", code: contract.tariff, capture: capture)
                LabeledContent("Format", value: String(format: "%02X", contract.structure))
                Text("Le rôle du second titre et les intitulés commerciaux restent à confirmer. Un emplacement n’est pas un numéro d’abonnement. Le prix correspond à l’achat du titre, pas à chaque trajet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }

    private func eventRow(_ event: RegionalEvent, capture: RegionalCardCapture) -> some View {
        let placeField = "place:\(event.provider ?? -1):\(event.mode)"
        let customPlace = capture.ticketingNetworkID.flatMap { network in
            event.location.flatMap { RegionalCodeLabels(json: codeLabelsJSON).label(network: network, field: placeField, code: $0) }
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label(capture.transportRegion == .lignesAzur && event.provider == 25 && event.mode == 4 && event.route == 1 ? "Tram 1 · \(event.transitionLabel)" : "\(capture.eventRouteName(event) ?? event.modeLabel) · \(event.transitionLabel)", systemImage: event.symbol).font(.headline)
            Text(capture.regionalPlace(for: event) ?? customPlace ?? event.location.map { "Lieu à identifier · \($0)" } ?? "Lieu non renseigné")
                .font(.title3.weight(.medium))
            Text(event.header.label).font(.subheadline).foregroundStyle(.secondary)
            if let result = event.result {
                Text("Résultat encodé : \(result)" + (result == 0 ? "" : " · à interpréter")).font(.caption).foregroundStyle(result == 0 ? Color.secondary : Color.orange)
            } else {
                Text("Résultat de validation non renseigné").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Détails de la validation") {
            if let route = event.route {
                if capture.transportRegion == .lignesAzur && event.provider == 25 && event.mode == 4 && route == 1 {
                    LabeledContent("Ligne", value: "Tram 1")
                } else { namedCode("Ligne", field: "route:\(event.provider ?? -1):\(event.mode)", code: route, capture: capture) }
            }
            if let place = event.location, capture.regionalPlace(for: event) == nil {
                namedCode("Nom du lieu", field: placeField, code: place, capture: capture)
            }
            if let provider = event.provider {
                if let name = capture.eventProviderName(provider) { LabeledContent("Transporteur", value: "\(name) · code \(provider)") }
                else { namedCode("Transporteur", field: "eventProvider", code: provider, capture: capture) }
            }

                if let first = event.firstStamp { LabeledContent("Première validation encodée", value: first.label) }
                if let result = event.result { LabeledContent("Code résultat", value: String(result)) }
                if let counter = event.notOKCounter { LabeledContent("Compteur « not OK » encodé", value: String(counter)) }
                if let serial = event.serialNumber { LabeledContent("Numéro de l’événement", value: String(serial)) }
                if let destination = event.destination { LabeledContent("Code destination", value: String(destination)) }
                if let run = event.journeyRun { LabeledContent("Code course", value: String(run)) }
                if let vehicle = event.vehicle { LabeledContent("Code véhicule", value: String(vehicle)) }
                if let direction = event.direction { LabeledContent("Code direction", value: String(direction)) }
                if let simulation = event.simulation { LabeledContent("Indicateur de simulation", value: String(simulation)) }
                if let amount = event.amount { LabeledContent("Montant brut de l’événement", value: String(amount)) }
                if let unit = event.monetaryUnit { LabeledContent("Code unité monétaire", value: String(unit)) }
                if let part = event.journeyPart { LabeledContent("Code tronçon", value: String(part)) }
                Text(event.hasUndecodedNonzeroBits ? "Des bits non interprétés subsistent." : "Le reste de cet enregistrement est nul (\(event.paddingBitCount) bits).")
                    .font(.footnote).foregroundStyle(.secondary)
                if let tail = event.undecodedTailHex {
                    DisclosureGroup("Données complémentaires à interpréter") {
                        Text(tail).font(.caption.monospaced()).textSelection(.enabled)
                        Text("Ces données sont conservées sans leur attribuer une signification non vérifiée.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let location = event.location { LabeledContent("Code de lieu", value: String(location)) }
                if let provider = event.provider { LabeledContent("Code transporteur", value: String(provider)) }
                if let pointer = event.contract { LabeledContent("Titre utilisé · emplacement", value: String(pointer)) }
                if let device = event.device {
                    LabeledContent("Code équipement enregistré", value: String(device))
                    if device == event.location {
                        Text("Ce code est identique au code du lieu. Il ne permet pas d’identifier une borne physique précise.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else { Text("Champ équipement absent de cet événement.").font(.footnote).foregroundStyle(.secondary) }
                if let gate = event.gate { LabeledContent("Code de passage", value: String(gate)) }
                if event.route == nil { Text("La carte ne fournit pas de numéro de ligne dans cet événement.").font(.footnote).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 6)
    }

    private var diagnostic: some View {
        NavigationStack {
            List {
                if archivedCapture == nil && reader.capture?.transportRegion == displayRegion {
                    Section("Recherche et lecture avancée") {
                    Button { reader.start() } label: {
                        Label("Recherche étendue · diagnostic", systemImage: "doc.text.magnifyingglass")
                    }.disabled(reader.isScanning)
                    if reader.canResume {
                        Button { reader.start(resuming: true) } label: {
                            Label("Reprendre la recherche", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                        }.buttonStyle(.borderless).disabled(reader.isScanning)
                    }
                    if displayedCapture?.exploration?.finished == true {
                        Button { reader.inspectSupport() } label: {
                            Label("Identifier l’interface NFC · lecture courte", systemImage: "antenna.radiowaves.left.and.right")
                        }.disabled(reader.isScanning)
                        Text("Recueille les informations de détection fournies par iOS et conserve tous les fichiers déjà lus.").font(.footnote).foregroundStyle(.secondary)
                        Button { reader.enumerateFiles() } label: {
                            Label("Vérifier l’inventaire direct des fichiers", systemImage: "list.bullet.rectangle")
                        }.disabled(reader.isScanning)
                        Button { reader.deepen() } label: {
                            Label("Recherche complémentaire · applications et dossiers", systemImage: "magnifyingglass")
                        }.disabled(reader.isScanning)
                    }

                        if reader.isScanning { ProgressView(reader.message) }
                        else { Text(reader.message).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                if let capture = displayedCapture {
                    if let uid = capture.exploration?.cardIdentifier,
                       let record = regionalHistory.records.first(where: { $0.capture.exploration?.cardIdentifier == uid }),
                       let scans = record.scans, scans.count > 1 {
                        Section("Lectures précédentes de cette carte") {
                            ForEach(scans.sorted { $0.date > $1.date }, id: \.date) { scan in
                                NavigationLink {
                                    RegionalCardView(archivedCapture: scan, region: scan.transportRegion)
                                } label: {
                                    Text(scan.date.formatted(date: .abbreviated, time: .shortened))
                                }
                            }
                            Text("Les lectures sont regroupées dans une seule carte de l’historique. Les rapports précédents restent consultables ici.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if !capture.directInventories.isEmpty {
                        Section("Inventaire direct des fichiers") {
                            ForEach(capture.directInventories) { inventory in
                                LabeledContent(inventory.label, value: "\(inventory.fileCount) fichiers · " + (inventory.endedNormally ? "fin de liste confirmée" : inventory.terminalStatus ?? "en cours"))
                            }
                            Text("Cette vérification porte sur les six applications connues. Elle ne garantit pas l’accès à toute la mémoire de la carte ni aux contenus protégés.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if !capture.regionalUninterpretedTitles.isEmpty {
                        Section("Compteurs bruts des titres") {
                            ForEach(capture.regionalUninterpretedTitles) { title in
                                if let value = capture.partialTitleCounter(title.id) {
                                    LabeledContent("Titre \(title.tariff) · emplacement \(title.id)", value: String(value))
                                }
                            }
                            Text("L’unité de ces compteurs reste à identifier. Ils ne sont pas présentés comme des voyages restants ou un montant.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if capture.hasMobibLayout {
                        Section("Fichiers MOBIB examinés") {
                            ForEach(capture.mobibLogInventory) { file in
                                LabeledContent("Fichier " + file.id, value: "\(file.recordsRead) lus · \(file.nonzeroRecords) non nuls")
                            }
                            Text("Un enregistrement nul ne contient pas de passage récupérable. Les champs inconnus des autres fichiers restent conservés ; ce bilan ne garantit pas que toute la mémoire de la carte soit accessible.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let environment = capture.regionalEnvironment {
                        Section("Support et profil") {
                            LabeledContent("Personnalisation", value: environment.personalizationLabel)
                            LabeledContent("Échéance technique", value: environment.expiryLabel)
                            Text("Cette échéance concerne l’application de billetterie du support. Ton abonnement conserve ses propres dates de validité.")
                                .font(.footnote).foregroundStyle(.secondary)
                            DisclosureGroup("Informations enregistrées sur le support") {
                                LabeledContent("Format de données", value: environment.versionLabel)
                                LabeledContent("Code réseau", value: String(format: "%06X", environment.network))
                                LabeledContent("Code émetteur", value: String(environment.issuer))
                                if let birth = environment.birthDate { LabeledContent("Date de naissance enregistrée", value: birth).privacySensitive() }
                                if let commercial = environment.commercialCode { LabeledContent("Code commercial du porteur", value: String(commercial)) }
                                Text("Le code commercial ne permet pas encore de nommer un profil étudiant ou un droit bus.").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let amc = capture.regionalAMC {
                        Section("Identifiants multiservices · AMC") {
                            Text("Cette zone identifie le support auprès de différents services. Ses \(amc.sectors.count) identifiants ne représentent pas des trajets.")
                                .font(.footnote).foregroundStyle(.secondary)
                            LabeledContent("Émetteur des identifiants", value: amc.issuerName ?? String(format: "%04X", amc.issuerReference))
                            LabeledContent("Date inscrite dans les données AMC", value: amc.encodedDate)
                            LabeledContent("Périmètre", value: "AMC commune · France")
                            LabeledContent("Bloc de signature", value: "\(amc.signatureByteCount) octets · non vérifié")
                            DisclosureGroup("Les \(amc.sectors.count) identifiants et leur rôle") {
                                ForEach(amc.sectors) { sector in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(sector.id) · \(sector.name)")
                                        Text(String(format: "Identifiant : %08X · référence de clé : %04X", sector.value, sector.keyReference))
                                            .font(.caption.monospaced()).foregroundStyle(.secondary).privacySensitive()
                                    }
                                }
                            }
                            Text("La présence d’un identifiant Transports ne prouve ni son utilisation par le bus 59 ni le stockage de ses validations dans cette zone.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Link("Comprendre l’AMC · ADCET", destination: URL(string: "https://www.adcet.org/amc/la-norme/faq/")!)
                        }
                    }
                    if let metadata = capture.nfcMetadata {
                        Section("Technologie observée du support") {
                            Text(metadata.observedProtocol)
                            Text("Ces informations décrivent l’interface détectée par iOS. Elles ne permettent pas, à elles seules, d’exclure une seconde technologie sur la carte.")
                                .font(.footnote).foregroundStyle(.secondary)
                            DisclosureGroup("Identification technique") {
                                LabeledContent("Identifiant NFC", value: metadata.identifier).privacySensitive()
                                LabeledContent("Application sélectionnée au démarrage", value: metadata.initialSelectedAID)
                                if let data = metadata.historicalBytes, !data.isEmpty { LabeledContent("Réponse Type A", value: data) }
                                if let data = metadata.applicationData, !data.isEmpty { LabeledContent("Réponse Type B", value: data) }
                            }
                        }
                    }
                    Section("Rapport de recherche") {
                        ShareLink(item: capture.json) { Label("Partager la lecture", systemImage: "square.and.arrow.up") }
                        Text("Le rapport contient les réponses brutes, y compris les refus et les fichiers non décodés. Il peut contenir des données personnelles.")
                            .font(.footnote).foregroundStyle(.secondary)
                        DisclosureGroup("Voir les données brutes") {
                            Text(capture.json).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                    if archivedCapture == nil, let previous = reader.previousCapture {
                        Section("Lecture précédente") {
                            ShareLink(item: previous.json) { Label("Partager la lecture précédente", systemImage: "square.and.arrow.up") }
                            if let difference = RegionalCaptureDifference(previous: previous, current: capture) {
                                Text("\(difference.changed.count) emplacements modifiés · \(difference.added.count) nouvellement lus · \(difference.missing.count) non relus")
                                ForEach(difference.changed, id: \.self) { Text($0).font(.caption.monospaced()) }
                            }
                        }
                    }
                    if let blocked = capture.exploration?.undeclaredApplications, !blocked.isEmpty {
                        Section("Accès à autoriser dans une mise à jour") {
                            Text("iOS exige une autorisation intégrée à l’app pour ces identifiants. Les autres lectures ont continué.")
                            ForEach(blocked, id: \.self) { Text($0).font(.caption.monospaced()) }
                        }
                    }
                    let pinFiles = capture.regionalFileHeaders.filter(\.requiresPIN)
                    if !pinFiles.isEmpty {
                        Section("Fichiers protégés par PIN") {
                            ForEach(pinFiles) { file in
                                LabeledContent(file.path, value: "\(file.recordSize * file.recordCount) octets")
                            }
                            Text("Les paramètres de ces fichiers exigent un PIN de la carte. Leur contenu n’a pas été lu. Aucun PIN n’a été essayé ; leur lien avec les bus est inconnu.")
                                .font(.footnote).foregroundStyle(.secondary)

                        }
                    }
                    Section("Diagnostic des accès protégés") {
                        Button {
                            showsDiagnostic = false
                            reader.checkProtectedAccess()
                        } label: {
                            Label("Vérifier l’état des accès · sans présenter de PIN", systemImage: "lock.doc")
                        }.disabled(archivedCapture != nil || reader.isScanning || reader.canResume)
                        Text("Cette consultation n’essaie aucun code et ne déverrouille pas les fichiers. Elle reste disponible après une lecture rapide, même sans en-têtes des fichiers protégés.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    let pinReplies = capture.exchanges.filter { $0.operation == RegionalPINStatus.operation }
                    if !pinReplies.isEmpty {
                        Section("État du PIN · aucun code essayé") {
                            Text("Le compteur est interprété à partir du statut retourné. Pour 9000, Keyple, l’implémentation de référence Calypso, retient 3 essais ; la réponse ne contient pas le chiffre 3 en clair.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Link("Voir le décodage de référence Keyple", destination: URL(string: "https://github.com/eclipse-keyple/keyple-card-calypso-java-lib/blob/main/src/main/java/org/eclipse/keyple/card/calypso/CommandVerifyPin.java")!)
                            ForEach(Array(pinReplies.enumerated()), id: \.offset) { _, reply in
                                VStack(alignment: .leading) {
                                    Text(reply.application == "334D54522E494341" ? "Fichier 0003" : "Fichier 2300/2302")
                                    Text(RegionalPINStatus.label(statusWord: reply.statusWord)).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    let shared = Dictionary(grouping: capture.regionalFileHeaders.filter { $0.sharedReference != 0 }, by: \.sharedReference).values.filter { $0.count > 1 }
                    if !shared.isEmpty {
                        Section("Données partagées entre applications") {
                            Text("\(shared.count) groupes de fichiers renvoient aux mêmes données partagées. Plusieurs applications ne signifient donc pas autant d’historiques différents.")
                                .font(.footnote)
                        }
                    }
                    if !capture.regionalFileHeaders.isEmpty {
                        Section("Inventaire du support") {
                            DisclosureGroup("\(capture.regionalFileHeaders.count) fichiers identifiés") {
                                ForEach(capture.regionalFileHeaders) { file in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(file.path).font(.caption.monospaced())
                                        Text("\(file.recordCount) × \(file.recordSize) octets · \(file.readAccessLabel)").font(.footnote)
                                        if file.sharedReference != 0 {
                                            Text(String(format: "Référence de données partagées : %04X", file.sharedReference)).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            Text("Un fichier identifié peut rester non lu ou non décodé. L’inventaire ne garantit pas une copie de toute la mémoire de la carte.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section("Portée de la recherche") {
                        Text("Le scan teste les dossiers candidats et demande les listes de fichiers accessibles. Une recherche terminée ne garantit pas une copie intégrale de la puce. Un fichier non décodé n’est pas présenté comme un trajet.")
                    }
                }
            }
            .navigationTitle("Informations et développement")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { showsDiagnostic = false }
                }
            }
        }
    }
}
#endif
