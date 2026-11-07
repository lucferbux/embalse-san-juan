import AppIntents
import EmbalseKit

/// The reservoir a widget or complication shows. Compiled into the app and both widget extensions, so WidgetKit and
/// the app agree on the type.
enum ReservoirChoice: String, AppEnum {
    case sanJuan, burguillo, picadas

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Embalse"
    static let caseDisplayRepresentations: [ReservoirChoice: DisplayRepresentation] = [
        .sanJuan: "San Juan",
        .burguillo: "Burguillo",
        .picadas: "Picadas",
    ]

    var reservoir: ReservoirID {
        switch self {
        case .sanJuan: .sanJuan
        case .burguillo: .burguillo
        case .picadas: .picadas
        }
    }
}

struct SelectReservoirIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Embalse"
    static let description = IntentDescription("Elige qué embalse del Alberche muestra el widget.")

    @Parameter(title: "Embalse", default: .sanJuan)
    var reservoir: ReservoirChoice

    init() {}
    init(reservoir: ReservoirChoice) { self.reservoir = reservoir }
}

/// Opens the app, for the Control Center control and the Action button.
struct OpenReservoirIntent: AppIntent {
    static let title: LocalizedStringResource = "Abrir Embalse San Juan"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}
