import EmbalseKit
import SwiftUI

/// The app's three sections (docs/design/review-2.0/SYNTHESIS.md): Ahora, Histórico and El río, in a system tab view
/// whose bar is Liquid Glass on iOS 27. On regular widths it adapts into a sidebar, where Burguillo and Picadas are
/// destinations of their own. The ficha, sources, alerts, suggestions and tips are reached from the toolbar.
enum AppTab: String, Hashable { case now, year, river, burguillo, picadas }

enum Route: Hashable {
    case about, suggestions, tips, alerts
    case reservoir(ReservoirID)
    case detail(NowDetail)
}

struct RootView: View {
    var model: ReservoirModel
    @State private var history = HistoryModel()
    @State private var tab: AppTab = Self.initialTab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView().controlSize(.large)
            case .failed:
                ContentUnavailableView {
                    Label("No se ha podido cargar", systemImage: "wifi.slash")
                } description: {
                    Text("Revisa la conexión e inténtalo de nuevo.")
                } actions: {
                    Button("Reintentar") { Task { await model.refresh(force: true) } }
                        .buttonStyle(.borderedProminent)
                }
            case .loaded(let snapshot, let origin):
                tabs(snapshot, origin)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }

    private func tabs(_ snapshot: Snapshot, _ origin: SnapshotRepository.Origin) -> some View {
        TabView(selection: $tab) {
            Tab("Ahora", systemImage: "drop.fill", value: AppTab.now) {
                TabStack(snapshot: snapshot) {
                    NowView(snapshot: snapshot, origin: origin, history: history, refresh: { await model.refresh(force: true) })
                }
            }
            Tab("Histórico", systemImage: "chart.xyaxis.line", value: AppTab.year) {
                TabStack(snapshot: snapshot) {
                    YearView(snapshot: snapshot, history: history)
                }
            }
            TabSection("El río") {
                Tab("El río", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: AppTab.river) {
                    TabStack(snapshot: snapshot) {
                        RiverView(snapshot: snapshot, history: history)
                    }
                }
                if horizontalSizeClass == .regular {
                Tab("Burguillo", systemImage: "drop", value: AppTab.burguillo) {
                    TabStack(snapshot: snapshot) { ReservoirPage(id: .burguillo, snapshot: snapshot) }
                }
                .tabPlacement(.sidebarOnly)
                .defaultVisibility(.hidden, for: .tabBar)
                Tab("Picadas", systemImage: "drop", value: AppTab.picadas) {
                    TabStack(snapshot: snapshot) { ReservoirPage(id: .picadas, snapshot: snapshot) }
                }
                .tabPlacement(.sidebarOnly)
                .defaultVisibility(.hidden, for: .tabBar)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(history)
    }

    private static var initialTab: AppTab {
        #if DEBUG
        // `-ScreenshotTab year` opens a section directly, for scripts/export-screenshots.sh and capture-matrix.sh.
        if let tab = UserDefaults.standard.string(forKey: "ScreenshotTab").flatMap(AppTab.init(rawValue:)) { return tab }
        #endif
        return .now
    }
}

/// A navigation stack per tab, with the shared toolbar and destinations.
private struct TabStack<Content: View>: View {
    var snapshot: Snapshot
    @ViewBuilder var content: Content
    @State private var path: [Route] = Self.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            content
                .toolbar { AppToolbar(snapshot: snapshot) }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .about: AboutView(snapshot: snapshot)
                    case .suggestions: SuggestionView()
                    case .tips: TipJarView()
                    case .alerts: AlertsView()
                    case .reservoir(let id): ReservoirPage(id: id, snapshot: snapshot)
                    case .detail(let detail): NowDetailView(detail: detail, snapshot: snapshot)
                    }
                }
        }
    }

    private static var initialPath: [Route] {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "ScreenshotScene") {
        case "about": return [.about]
        case "suggestions": return [.suggestions]
        case "tips": return [.tips]
        case "alerts": return [.alerts]
        case "burguillo": return [.reservoir(.burguillo)]
        default: return []
        }
        #else
        return []
        #endif
    }
}

private struct AppToolbar: ToolbarContent {
    var snapshot: Snapshot
    @State private var jar = TipJar()

    private var showsTips: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "ScreenshotTips") { return true }
        #endif
        // Tips stay hidden until the App Store offers them.
        return jar.state == .ready
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ShareLink(item: ShareCard.image(for: snapshot), preview: SharePreview(Text("San Juan, \(Format.percent(snapshot.live.percent))"), image: ShareCard.image(for: snapshot))) {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                NavigationLink(value: Route.alerts) { Label("Avisos", systemImage: "bell") }
                NavigationLink(value: Route.about) { Label("Ficha y fuentes", systemImage: "info.circle") }
                NavigationLink(value: Route.suggestions) { Label("Enviar una sugerencia", systemImage: "bubble.left.and.text.bubble.right") }
                if showsTips {
                    NavigationLink(value: Route.tips) { Label("Dejar una propina", systemImage: "cup.and.heat.waves") }
                }
            } label: {
                Label("Más", systemImage: "ellipsis")
            }
            .task { await jar.load() }
        }
    }
}

/// Every reservoir's history, loaded on demand and kept offline by `HistoryRepository`.
@MainActor
@Observable
final class HistoryModel {
    enum State: Equatable { case idle, loading, loaded(History), failed }

    private(set) var states: [ReservoirID: State] = [:]
    private let repository = HistoryRepository()

    func state(_ id: ReservoirID) -> State { states[id] ?? .idle }

    func history(_ id: ReservoirID) -> History? {
        if case .loaded(let history) = state(id) { return history }
        return nil
    }

    func load(_ id: ReservoirID) async {
        if case .loaded = state(id) { return }
        if let cached = repository.cached(id) { states[id] = .loaded(cached) } else { states[id] = .loading }
        do {
            states[id] = .loaded(try await repository.load(id))
        } catch {
            if history(id) == nil { states[id] = .failed }
        }
    }
}
