import EmbalseKit
import SwiftUI

struct AboutView: View {
    var snapshot: Snapshot

    var body: some View {
        let reservoir = snapshot.reservoir
        List {
            Section("Ficha") {
                LabeledContent("Río", value: reservoir.river)
                LabeledContent("Cuenca", value: reservoir.basin)
                LabeledContent("Provincia", value: reservoir.province)
                LabeledContent("Municipio", value: reservoir.municipality)
                LabeledContent("Tipo de presa", value: reservoir.damType)
                LabeledContent("Año de construcción", value: String(reservoir.yearBuilt))
                LabeledContent("Superficie", value: "\(Format.number(reservoir.surfaceHa, decimals: 0)) ha")
            }
            Section("Usos") {
                ForEach(reservoir.uses, id: \.self) { Text($0) }
            }
            Section {
                ForEach(snapshot.sources) { source in
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                Text(source.publisher)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(source.note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Fuentes")
            } footer: {
                Text("App personal, sin relación con estos organismos ni respaldada por ellos. Todos los datos son provisionales.")
            }
            Section {
                if let url = URL(string: "https://embalse-san-juan.web.app/privacy.html") {
                    Link("Política de privacidad", destination: url)
                }
                if let url = URL(string: "https://embalse-san-juan.web.app/support.html") {
                    Link("Soporte", destination: url)
                }
            }
        }
        .navigationTitle("Ficha y fuentes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
