import BackgroundTasks
import EmbalseKit
import SwiftUI
import UserNotifications

/// Local alerts (docs/decisions/0003-local-notifications.md): the device checks the public snapshot in the background
/// and notifies when the level crosses the chosen threshold or the outflow jumps. No tokens, nothing leaves the device.
/// iOS decides when background refresh runs, so alerts can arrive late; the settings screen says so.
enum AlertSettings {
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: SnapshotCache.appGroup) ?? .standard
    static let enabledKey = "alerts.enabled"
    static let thresholdKey = "alerts.threshold"
    static let outflowKey = "alerts.outflow"
    static let lastPercentKey = "alerts.lastPercent"
    static let lastOutflowKey = "alerts.lastOutflow"

    static var enabled: Bool { defaults.bool(forKey: enabledKey) }
    static var threshold: Double { defaults.object(forKey: thresholdKey) as? Double ?? 50 }
    static var outflow: Bool { defaults.bool(forKey: outflowKey) }
}

/// What to say, decided from the previous and the new reading. Pure, so it is tested without notifications.
enum AlertRule {
    /// A release counts as big when the outflow at least triples and reaches 10 m³/s.
    static let bigOutflow = 10.0

    static func messages(previousPercent: Double?, percent: Double, threshold: Double,
                         previousOutflow: Double?, outflow: Double?, watchOutflow: Bool) -> [String] {
        var messages: [String] = []
        if let previousPercent {
            if previousPercent < threshold, percent >= threshold {
                messages.append(String(localized: "San Juan ha superado el \(Format.percent(threshold)): está al \(Format.percent(percent))."))
            } else if previousPercent >= threshold, percent < threshold {
                messages.append(String(localized: "San Juan ha bajado del \(Format.percent(threshold)): está al \(Format.percent(percent))."))
            }
        }
        if watchOutflow, let previousOutflow, let outflow, outflow >= bigOutflow, outflow >= previousOutflow * 3 {
            messages.append(String(localized: "Desembalse: la salida al río ha pasado de \(Format.value(previousOutflow, .flow, unit: "m³/s")) a \(Format.value(outflow, .flow, unit: "m³/s"))."))
        }
        return messages
    }
}

enum AlertScheduler {
    static let taskID = "com.lucferbux.embalsesanjuan.refresh"

    /// Asks for the next check in about an hour, when new data lands. iOS may run it later.
    static func schedule() {
        guard AlertSettings.enabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
            return
        }
        Task {
            let request = BGAppRefreshTaskRequest(identifier: taskID)
            request.earliestBeginDate = .now.addingTimeInterval(3600)
            try? await BGTaskScheduler.shared.submitTaskRequest(request)
        }
    }

    /// One check: fetch, compare with the last reading the device saw, notify, remember.
    static func check() async {
        schedule()
        guard AlertSettings.enabled, let snapshot = try? await SnapshotRepository().load().snapshot else { return }
        let defaults = AlertSettings.defaults
        let messages = AlertRule.messages(
            previousPercent: defaults.object(forKey: AlertSettings.lastPercentKey) as? Double,
            percent: snapshot.live.percent,
            threshold: AlertSettings.threshold,
            previousOutflow: defaults.object(forKey: AlertSettings.lastOutflowKey) as? Double,
            outflow: snapshot.live.outflowM3s,
            watchOutflow: AlertSettings.outflow)
        defaults.set(snapshot.live.percent, forKey: AlertSettings.lastPercentKey)
        if let outflow = snapshot.live.outflowM3s { defaults.set(outflow, forKey: AlertSettings.lastOutflowKey) }
        for message in messages {
            let content = UNMutableNotificationContent()
            content.title = "Embalse San Juan"
            content.body = message
            content.subtitle = Format.saihSource(snapshot.live.observedAt)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

struct AlertsView: View {
    @AppStorage(AlertSettings.enabledKey, store: AlertSettings.defaults) private var enabled = false
    @AppStorage(AlertSettings.thresholdKey, store: AlertSettings.defaults) private var threshold = 50.0
    @AppStorage(AlertSettings.outflowKey, store: AlertSettings.defaults) private var outflow = false
    @State private var denied = false

    var body: some View {
        Form {
            Section {
                Toggle("Avisarme", isOn: $enabled)
            } footer: {
                Text("El iPhone comprueba el dato público cada cierto tiempo. iOS decide cuándo, así que un aviso puede llegar con retraso. No se envía nada desde el teléfono.")
            }
            if enabled {
                Section("Nivel") {
                    Stepper(value: $threshold, in: 10...90, step: 5) {
                        ValueRow("Cuando cruce el", value: Format.percent(threshold))
                    }
                }
                Section {
                    Toggle("Desembalses grandes", isOn: $outflow)
                } footer: {
                    Text("Cuando la salida al río se triplica y supera los \(Format.value(AlertRule.bigOutflow, .flow, unit: "m³/s")).")
                }
            }
            if denied {
                Section {
                    Label("Las notificaciones están desactivadas para la app en Ajustes.", systemImage: "bell.slash").foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Avisos")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: enabled) { _, on in
            Task {
                if on {
                    let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                    denied = !granted
                }
                AlertScheduler.schedule()
            }
        }
    }
}
