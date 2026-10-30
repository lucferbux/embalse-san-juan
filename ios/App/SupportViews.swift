import EmbalseKit
import StoreKit
import SwiftUI

struct SuggestionView: View {
    private enum Status: Equatable {
        case editing, sending, sent, failed
    }

    @State private var kind = Suggestion.Kind.suggestion
    @State private var text = ""
    @State private var status = Status.editing
    @FocusState private var isEditing: Bool

    private var suggestion: Suggestion { Suggestion(kind: kind, text: text) }

    var body: some View {
        Form {
            if status == .sent {
                ContentUnavailableView {
                    Label("Gracias por escribir", systemImage: "checkmark.circle")
                } description: {
                    Text("Tu mensaje ha llegado. Lo leeré, aunque no pueda responderte porque es anónimo.")
                } actions: {
                    Button("Enviar otro") {
                        text = ""
                        status = .editing
                    }
                }
            } else {
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(Suggestion.Kind.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .focused($isEditing)
                        .accessibilityLabel("Tu mensaje")
                } header: {
                    Text("Tu mensaje")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(suggestion.trimmedText.count) de \(Suggestion.maximumLength) caracteres.")
                            .foregroundStyle(suggestion.trimmedText.count > Suggestion.maximumLength ? .red : .secondary)
                        Text("Es anónimo: no incluyas datos personales. Si quieres respuesta, escribe desde la página de soporte.")
                    }
                }
                if status == .failed {
                    Section {
                        Label("No se ha podido enviar. Revisa la conexión e inténtalo de nuevo.", systemImage: "wifi.slash")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("Sugerencias")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if status != .sent {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar", systemImage: "paperplane") {
                        Task { await send() }
                    }
                    .disabled(!suggestion.isValid || status == .sending)
                }
            }
        }
    }

    private func send() async {
        status = .sending
        isEditing = false
        do {
            try await SuggestionClient().send(suggestion)
            status = .sent
        } catch {
            status = .failed
        }
    }
}

struct TipJarView: View {
    @State private var jar = TipJar()
    @Environment(\.purchase) private var purchase

    var body: some View {
        List {
            Section {
                Text("La app es gratuita y seguirá siéndolo. Si te resulta útil, una propina ayuda a cubrir los gastos de mantenimiento.")
            } footer: {
                Text("Es un pago único y voluntario, y no desbloquea nada. Lo gestiona Apple.")
            }
            Section {
                content
            }
        }
        .navigationTitle("Dejar una propina")
        .navigationBarTitleDisplayMode(.inline)
        .task { await jar.load() }
        .alert("¡Muchas gracias!", isPresented: Binding(get: { jar.thanked }, set: { _ in jar.dismissThanks() })) {
            Button("De nada", role: .confirm) {}
        } message: {
            Text("Tu propina ayuda a mantener la app en marcha.")
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "ScreenshotTips") {
            TipRow(title: "Propina pequeña", detail: "Un café para el mantenimiento", price: "0,99 €", isBusy: false) {}
            TipRow(title: "Propina mediana", detail: "Un mes de mantenimiento", price: "2,99 €", isBusy: false) {}
            TipRow(title: "Propina grande", detail: "Varios meses de mantenimiento", price: "4,99 €", isBusy: false) {}
        } else {
            liveContent
        }
        #else
        liveContent
        #endif
    }

    @ViewBuilder
    private var liveContent: some View {
        switch jar.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .unavailable:
            Label("Las propinas no están disponibles ahora mismo.", systemImage: "exclamationmark.circle")
                .foregroundStyle(.secondary)
        case .ready:
            ForEach(jar.products) { product in
                TipRow(title: product.displayName, detail: product.description, price: product.displayPrice, isBusy: jar.purchasing == product.id) {
                    Task { await jar.buy(product) { try await purchase($0) } }
                }
                .disabled(jar.purchasing != nil)
            }
            if jar.failed {
                Label("No se ha podido completar el pago.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct TipRow: View {
    var title: String
    var detail: String
    var price: String
    var isBusy: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isBusy {
                    ProgressView()
                } else {
                    Text(price)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
    }
}
