//
//  HistoryPageView.swift
//  TransportReader
//
//  Created by Antoine Souben-Fink on 30/12/2026.
//  Edited by Célian Faucille on 10/01/2026

import SwiftUI


struct HistoryPageView: View {
    @ObservedObject var historyManager: HistoryManager
    #if os(iOS)
    @ObservedObject private var regionalHistory = RegionalHistory.shared
    #endif
    @AppStorage(HistoryManager.settingKey) private var isHistoryEnabled = false

    // Ligne en cours de déplacement d'une section à l'autre : elle est retirée
    // des deux listes le temps que son retrait s'anime, puis réinsérée à sa
    // nouvelle place. Sans ça SwiftUI retire et insère dans la même passe, et
    // le déplacement inter-sections n'est pas animé.
    @State private var movingRecordID: UUID?

    private static let moveDuration = 0.3

    private var pinned: [ScanRecord] {
        historyManager.pinnedRecords.filter { $0.id != movingRecordID }
    }

    private var unpinned: [ScanRecord] {
        historyManager.unpinnedRecords.filter { $0.id != movingRecordID }
    }

    private func movePin(_ record: ScanRecord) {
        guard movingRecordID == nil else { return }

        // 1. La ligne disparaît, le trou se referme.
        withAnimation(.easeInOut(duration: Self.moveDuration)) {
            movingRecordID = record.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.moveDuration) {
            // La ligne est masquée : basculer l'épinglage ne se voit pas.
            historyManager.togglePin(for: record)

            // 2. Un trou s'ouvre à la nouvelle place et la ligne le remplit.
            withAnimation(.easeInOut(duration: Self.moveDuration)) {
                movingRecordID = nil
            }
        }
    }

    #if os(iOS)
    private enum RecentRecord: Identifiable {
        case navigo(ScanRecord)
        case zou(RegionalHistoryRecord)
        var id: String {
            switch self {
            case .navigo(let record): return "navigo:" + record.id.uuidString
            case .zou(let record): return "zou:" + record.id
            }
        }
        var date: Date {
            switch self {
            case .navigo(let record): return record.date
            case .zou(let record): return record.mostRecentDate
            }
        }
    }
    private var recentRecords: [RecentRecord] {
        (unpinned.map(RecentRecord.navigo) + regionalHistory.records.map(RecentRecord.zou)).sorted { $0.date > $1.date }
    }
    #endif

    private var historyIsEmpty: Bool {
        #if os(iOS)
        historyManager.history.isEmpty && regionalHistory.records.isEmpty
        #else
        historyManager.history.isEmpty
        #endif
    }

    var body: some View {
        List {
            // Section des épinglés
            if !pinned.isEmpty {
                Section(header: HStack {
                    Image(systemName: "pin.fill")
                    Text("Épinglés")
                }.foregroundColor(.yellow)) {
                    ForEach(pinned) { record in
                        HistoryRowButton(record: record, historyManager: historyManager) {
                            movePin(record)
                        }
                    }
                }
            }

            // Section des récents. Sans épinglés, pas de titre : l'onglet dit
            // déjà « Historique ».
            Section {
                #if os(iOS)
                ForEach(recentRecords) { item in
                    switch item {
                    case .navigo(let record):
                        HistoryRowButton(record: record, historyManager: historyManager) { movePin(record) }
                    case .zou(let record):
                        NavigationLink {
                            RegionalCardView(archivedCapture: record.capture, region: record.capture.transportRegion)
                        } label: {
                            HStack(spacing: 14) {
                                RegionalCardArtwork(region: record.capture.transportRegion, imageName: record.imageName).frame(width: 88)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.displayTitle).font(.headline)
                                    Text(record.capture.decodedJourneyCount > 0 ? "\(record.capture.decodedJourneyCount) événements lus" : record.capture.hasFileRead ? "Aucun événement décodé" : (record.capture.usesEarlierTicketingReads || record.capture.usesEarlierMobibReads) ? "Dernières données conservées" : "Support détecté · lecture à compléter").font(.caption).foregroundStyle(.secondary)
                                    Text(record.mostRecentDate.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
                .onDelete { indices in
                    let items = indices.map { recentRecords[$0] }
                    historyManager.supprimer(Set(items.compactMap { if case .navigo(let record) = $0 { return record.id }; return nil }))
                    regionalHistory.delete(Set(items.compactMap { if case .zou(let record) = $0 { return record.id }; return nil }))
                }
                if let error = regionalHistory.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                #else
                ForEach(unpinned) { record in
                    HistoryRowButton(record: record, historyManager: historyManager) {
                        movePin(record)
                    }
                }
                .onDelete { indexSet in
                    // Les index portent sur la liste affichée, pas sur l'historique
                    historyManager.supprimer(Set(indexSet.map { unpinned[$0].id }))
                }
                #endif
            } header: {
                if !pinned.isEmpty {
                    Text("Récents")
                }
            }
        }
        .modifier(TransportReadableList())
        #if os(iOS)
        .onAppear { migrateRegionalCapture() }
        .onChange(of: isHistoryEnabled) { _, _ in migrateRegionalCapture() }
        #endif
        .overlay {
            // L'historique est éteint d'origine : sans ce mot, la page vide
            // ne dit ni pourquoi elle l'est, ni ce qu'on gagnerait à l'allumer.
            if historyIsEmpty {
                if isHistoryEnabled {
                    ContentUnavailableView {
                        Label("Aucun scan", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Les cartes que tu scannes ou importes s'enregistreront ici.")
                    }
                } else {
                    ContentUnavailableView {
                        Label("Historique désactivé", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("En activant l'historique, tu gardes la mémoire de tes déplacements passés et tu peux consulter tes anciens scans.")
                    } actions: {
                        Button("Activer l'historique") {
                            withAnimation { isHistoryEnabled = true }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
    #if os(iOS)
    private func migrateRegionalCapture() {
        let key = "regionalHistoryInitialImport.v1"
        guard isHistoryEnabled, !UserDefaults.standard.bool(forKey: key),
              let capture = RegionalCardReader.shared.capture, capture.exploration?.finished == true else { return }
        regionalHistory.save(capture, enabled: true)
        if regionalHistory.error == nil { UserDefaults.standard.set(true, forKey: key) }
    }
    #endif

}

#Preview {
    HistoryPageView(historyManager: HistoryManager())
}
