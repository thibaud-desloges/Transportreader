import SwiftUI

struct TransportRegionPicker: View {
    @Binding var selection: String
    var onSelection: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Régions disponibles") {
                    ForEach(TransportRegion.allCases) { region in
                        Button {
                            onSelection?()
                            selection = region.rawValue
                            dismiss()
                        } label: {
                            HStack(spacing: 16) {
                                Image(region.logoAsset).resizable().scaledToFit()
                                    .padding(4)
                                    .frame(width: 76, height: 44)
                                    .background(region == .passPass ? Color(red: 0.31, green: 0.18, blue: 0.56) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(region.name).font(.headline).foregroundStyle(.primary)
                                    Text(region.network).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selection == region.rawValue { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
                            }.padding(.vertical, 8)
                        }
                    }
                }
                Section { Text("D’autres régions pourront être ajoutées ici.").foregroundStyle(.secondary) }
            }
            .modifier(TransportReadableList())
            .navigationTitle("Choisir une région")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
        }
    }
}

struct ZouCardArtwork: View {
    var compact = false
    var body: some View {
        Image("ZouCard")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("Recto bleu de la carte ZOU!")
    }
}

struct RegionalCardArtwork: View {
    var region: TransportRegion
    var imageName: String? = nil
    var body: some View {
        GeometryReader { geometry in
            Image(imageName.flatMap { $0.isEmpty ? nil : $0 } ?? region.cardAsset).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: geometry.size.width * 0.028))
                .accessibilityLabel("Carte \(region.network)")
        }.aspectRatio(86.0 / 54.0, contentMode: .fit)
    }
}

struct RegionalArtworkPicker: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void
    private var images: [String] {
        Array(Set(TransportRegion.allCases.map(\.cardAsset) + PassCatalog.categories.flatMap(\.images))).sorted()
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Button("Visuel automatique du réseau") { onSelect(""); dismiss() }.padding()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220))], spacing: 20) {
                        ForEach(images, id: \.self) { image in
                            Button { onSelect(image); dismiss() } label: {
                                Image(image).resizable().scaledToFit().frame(height: 100)
                            }.buttonStyle(.plain).accessibilityLabel(image)
                        }
                    }.padding()
                }
            }
            .navigationTitle("Choisir une image")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
    }
}
