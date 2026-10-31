//
//  ScanPageView.swift
//  TransportReader
//
//  Created by Antoine Souben-Fink on 30/12/2025.
//


import SwiftUI

struct ScanPageView: View {
    @ObservedObject var nfcReader: NFCReader
    @ObservedObject var historyManager: HistoryManager
    #if os(iOS)
    @AppStorage("autoLaunchScan") private var autoLaunchScan = false
    @State private var hasAutoLaunched = false
    #endif
    @State private var isImporting = false
    @State private var showsRegionPicker = false
    @State private var showsResearch = false
    @AppStorage(TransportRegion.settingKey) private var selectedRegion = TransportRegion.ileDeFrance.rawValue
    #if os(iOS)
    @ObservedObject private var regionalReader = RegionalCardReader.shared
    #endif

    // Tant qu'aucune carte n'est lue en entier, on n'affiche que l'état vide :
    // les boutons de scan, de menu et de partage restent masqués. C'est la
    // lecture achevée qui compte, pas l'en-tête reçu : la cible tient l'écran
    // jusqu'au bout plutôt que de céder la place à un passe encore à moitié vide.
    private var hasCard: Bool { nfcReader.isReadComplete }

    var body: some View {
        Group {
            #if os(iOS)
            if let region = TransportRegion(rawValue: selectedRegion), region.usesRegionalReader { RegionalCardView(region: region) }
            else { navigoContent }
            #else
            navigoContent
            #endif
        }
        .navigationTitle("")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    regionalReader.prepareForNewCard()
                    showsResearch = true
                } label: { Label("Recherche complète sur une carte", systemImage: "magnifyingglass") }
                .disabled(nfcReader.isScanning || regionalReader.isScanning)
            }
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    showsRegionPicker = true
                } label: {
                    Label("Choisir une région", systemImage: "globe.europe.africa")
                }
                .disabled(nfcReader.isScanning || regionalReader.isScanning)
                // Sans carte, l'écran vide porte déjà son propre bouton d'import
                if selectedRegion == TransportRegion.ileDeFrance.rawValue && hasCard {
                    Button(action: { isImporting = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }

                    Button(action: {
                        nfcReader.beginScanning(historyManager: historyManager)
                    }) {
                        Image(systemName: "wave.3.forward")
                    }
                }
            }
            #else
            ToolbarItemGroup {
                Button(action: { isImporting = true }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            #endif
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.metropass],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                selectedRegion = TransportRegion.ileDeFrance.rawValue
                nfcReader.importFile(at: url, historyManager: historyManager)
            case .failure(let error):
                print("Error picking file: \(error.localizedDescription)")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showsResearch) {
            NavigationStack {
                RegionalCardView(region: TransportRegion(rawValue: selectedRegion) ?? .ileDeFrance, researchOnly: true)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { showsResearch = false } } }
            }
        }
        .sheet(isPresented: $showsRegionPicker) {
            TransportRegionPicker(selection: $selectedRegion, onSelection: {
                regionalReader.prepareForNewCard()
                nfcReader.isReadComplete = false
            })
        }
        #endif
        #if os(iOS)
        .onAppear {
            if autoLaunchScan && !hasAutoLaunched {
                if TransportRegion(rawValue: selectedRegion)?.usesRegionalReader == true { regionalReader.start(quick: true) }
                else { nfcReader.beginScanning(historyManager: historyManager) }
                hasAutoLaunched = true
            }
        }
        #endif
    }
    private var navigoContent: some View {
        Group {
            if hasCard {
                ScanView(cardID: nfcReader.cardID, tagIcc: nfcReader.tagIcc, tagEnvHolder: nfcReader.tagEnvHolder, tagContracts: nfcReader.tagContracts, tagEvents: nfcReader.tagEvents, tagSpecialEvents: nfcReader.tagSpecialEvents, export: nfcReader.export, historyManager: historyManager)
            } else {
                EmptyScanView(
                    isScanning: nfcReader.isScanning,
                    isTagDetected: nfcReader.isTagDetected,
                    onScan: { nfcReader.beginScanning(historyManager: historyManager) },
                    onImport: { isImporting = true }
                )
            }
        }
    }

}

#Preview {
    ScanPageView(nfcReader: NFCReader(), historyManager: HistoryManager())
}
