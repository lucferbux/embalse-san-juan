import EmbalseKit
import SwiftUI

@main
struct EmbalseSanJuanApp: App {
    @State private var model = ReservoirModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task { await TipJar.finishPendingTransactions() }
        }
        .backgroundTask(.appRefresh(AlertScheduler.taskID)) {
            await AlertScheduler.check()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { AlertScheduler.schedule() }
        }
    }
}
