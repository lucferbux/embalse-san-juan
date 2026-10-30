import SwiftUI

@main
struct EmbalseSanJuanApp: App {
    @State private var model = ReservoirModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
