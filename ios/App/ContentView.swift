import Charts
import EmbalseKit
import SwiftUI

enum Route: Hashable {
    case history, about, suggestions, tips
}

struct ContentView: View {
    var model: ReservoirModel
    @State private var path: [Route] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch model.state {
                case .loading:
                    ProgressView("Cargando")
                case .failed:
                    ContentUnavailableView {
                        Label("No hay datos", systemImage: "wifi.slash")
                    } description: {
                        Text("Revisa la conexión e inténtalo de nuevo.")
                    } actions: {
                        Button("Reintentar") {
                            Task { await model.refresh(force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .loaded(let snapshot, let origin):
                    ReservoirScreen(snapshot: snapshot, origin: origin) {
                        await model.refresh(force: true)
                    }
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .history: HistoryView(weekly: snapshot.weekly)
                        case .about: AboutView(snapshot: snapshot)
                        case .suggestions: SuggestionView()
                        case .tips: TipJarView()
                        }
                    }
                }
            }
            .navigationTitle("San Juan")
        }
        // Charts format their axes from the environment, so they follow the app's Spanish text.
        .environment(\.locale, Locale(identifier: "es_ES"))
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        #if DEBUG
        .task { openScreenshotScene() }
        #endif
    }

    #if DEBUG
    /// `-ScreenshotScene history` opens a screen directly, for scripts/export-screenshots.sh.
    private func openScreenshotScene() {
        switch UserDefaults.standard.string(forKey: "ScreenshotScene") {
        case "history": path = [.history]
        case "about": path = [.about]
        case "suggestions": path = [.suggestions]
        case "tips": path = [.tips]
        default: break
        }
    }
    #endif
}

/// Layout follows size classes only, never idiom or orientation. That covers iPad, its splits, and
/// iPhone Duo: its outer display is compact and its inner display is regular in both directions.
private struct ReservoirScreen: View {
    var snapshot: Snapshot
    var origin: SnapshotRepository.Origin
    var refresh: @Sendable () async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var fold = FoldGeometry()

    var body: some View {
        if horizontalSizeClass == .regular {
            ScrollView {
                DashboardColumns(fold: fold) {
                    HeroSection(snapshot: snapshot, origin: origin)
                    RealtimeSection(snapshot: snapshot)
                    OutflowSection(snapshot: snapshot)
                } trailing: {
                    WeeklySection(weekly: snapshot.weekly)
                    WeatherSection(weather: snapshot.weather)
                    AlbercheSection(snapshot: snapshot)
                    LinksSection()
                }
                .environment(\.dashboardStyle, .cards)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onGeometryChange(for: FoldGeometry.self) { FoldGeometry($0) } action: { fold = $0 }
            .refreshable { await refresh() }
        } else {
            ScrollViewReader { proxy in
                List {
                    HeroSection(snapshot: snapshot, origin: origin)
                    RealtimeSection(snapshot: snapshot)
                    OutflowSection(snapshot: snapshot)
                    WeeklySection(weekly: snapshot.weekly)
                        .id("weekly")
                    WeatherSection(weather: snapshot.weather)
                    AlbercheSection(snapshot: snapshot)
                        .id("alberche")
                    LinksSection()
                }
                .refreshable { await refresh() }
                #if DEBUG
                .task {
                    if let target = UserDefaults.standard.string(forKey: "ScreenshotScroll") {
                        try? await Task.sleep(for: .milliseconds(300))
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
                #endif
            }
        }
    }
}

private struct LinksSection: View {
    /// Tips stay hidden until the App Store offers them, which needs the Paid Apps Agreement.
    @State private var jar = TipJar()

    private var showsTips: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "ScreenshotTips") { return true }
        #endif
        return jar.state == .ready
    }

    var body: some View {
        DashboardSection {
            NavigationLink(value: Route.history) {
                Label("Histórico desde 1988", systemImage: "chart.xyaxis.line")
            }
            NavigationLink(value: Route.about) {
                Label("Ficha y fuentes", systemImage: "info.circle")
            }
        }
        DashboardSection("Ayuda a mejorarla", footer: showsTips ? "La app es gratuita. Las propinas son voluntarias y ayudan a cubrir los gastos de mantenimiento." : nil) {
            NavigationLink(value: Route.suggestions) {
                Label("Enviar una sugerencia", systemImage: "bubble.left.and.text.bubble.right")
            }
            if showsTips {
                NavigationLink(value: Route.tips) {
                    Label("Dejar una propina", systemImage: "cup.and.heat.waves")
                }
            }
        }
        .task { await jar.load() }
    }
}

private struct HeroSection: View {
    var snapshot: Snapshot
    var origin: SnapshotRepository.Origin
    @ScaledMetric(relativeTo: .title) private var height = 280.0
    @Environment(\.dashboardStyle) private var style

    var body: some View {
        let live = snapshot.live
        let trend = Trend(change: live.trend24hHm3)
        let hero = AnimatedWater(percent: live.percent) { phase in
            WaterlineText(percent: live.percent, phase: phase, amplitude: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Spacer(minLength: 0)
                    Text(Format.percent(live.percent))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("\(Format.hm3(live.volumeHm3, decimals: 2)) de \(Format.hm3(snapshot.weekly.capacityHm3, decimals: 0))")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        Image(systemName: trend.symbol)
                        Text("\(trend.label) · \(Format.signed(live.trend24hHm3)) hm³ en 24 h")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .combine)

        switch style {
        case .list:
            Section {
                hero.listRowInsets(EdgeInsets())
            } footer: {
                HeroFooter(snapshot: snapshot, origin: origin)
            }
        case .cards:
            VStack(alignment: .leading, spacing: 8) {
                hero.clipShape(.rect(cornerRadius: 26, style: .continuous))
                HeroFooter(snapshot: snapshot, origin: origin)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }
}

private struct HeroFooter: View {
    var snapshot: Snapshot
    var origin: SnapshotRepository.Origin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if snapshot.isStale() {
                Label("Este dato tiene más de 6 horas. La recogida puede estar fallando.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if origin == .cache {
                Label("Sin conexión. Mostrando el último dato guardado.", systemImage: "wifi.slash")
            }
            Text("SAIH Tajo, \(Format.dayMonthHour(snapshot.live.observedAt)). Dato provisional.")
        }
    }
}

private struct RealtimeSection: View {
    var snapshot: Snapshot

    var body: some View {
        let live = snapshot.live
        DashboardSection("Tiempo real") {
            RecentChart(readings: snapshot.recent)
                .frame(height: 150)
                .padding(.vertical, 4)
            LabeledContent("Cota", value: Format.optional(live.elevationM, decimals: 2, unit: "m"))
            LabeledContent("Nivel", value: Format.optional(live.levelM, decimals: 2, unit: "m"))
            DisclosureGroup("Últimas lecturas") {
                let rows = Array(snapshot.recent.enumerated()).suffix(8).reversed()
                ForEach(rows, id: \.element.id) { index, reading in
                    let previous = index > 0 ? snapshot.recent[index - 1].volumeHm3 : nil
                    HStack {
                        Text(Format.dayMonthHour(reading.at))
                        Spacer()
                        Text(Format.number(reading.volumeHm3, decimals: 2))
                            .monospacedDigit()
                        Text(previous.map { Format.signed(reading.volumeHm3 - $0) } ?? "")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

private struct RecentChart: View {
    var readings: [Snapshot.RecentReading]

    var body: some View {
        let values = readings.map(\.volumeHm3)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let margin = max((high - low) * 0.3, 0.05)
        Chart(readings) { reading in
            LineMark(x: .value("Hora", reading.at), y: .value("Volumen", reading.volumeHm3))
                .foregroundStyle(Palette.waterTop)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .chartYScale(domain: (low - margin)...(high + margin))
        .chartYAxisLabel("hm³")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Format.hour(date))
                    }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge) // Axis labels can't reflow, so they stop growing here.
        .accessibilityLabel("Volumen en las últimas 24 horas")
    }
}

private struct OutflowSection: View {
    var snapshot: Snapshot

    var body: some View {
        DashboardSection("Caudal desembalsado") {
            LabeledContent("Salida al río", value: Format.optional(snapshot.live.outflowM3s, decimals: 2, unit: "m³/s"))
            LabeledContent("Trasvase a Valmayor", value: Format.optional(snapshot.live.transferM3s, decimals: 2, unit: "m³/s"))
            let readings = snapshot.recent.filter { $0.outflowM3s != nil }
            if !readings.isEmpty {
                Chart(readings) { reading in
                    AreaMark(x: .value("Hora", reading.at), y: .value("Caudal", reading.outflowM3s ?? 0))
                        .foregroundStyle(Palette.waterTop.opacity(0.25))
                        .interpolationMethod(.stepEnd)
                    LineMark(x: .value("Hora", reading.at), y: .value("Caudal", reading.outflowM3s ?? 0))
                        .foregroundStyle(Palette.waterTop)
                        .interpolationMethod(.stepEnd)
                }
                .chartYAxisLabel("m³/s")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(Format.hour(date))
                            }
                        }
                    }
                }
                .frame(height: 110)
                .padding(.vertical, 4)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .accessibilityLabel("Caudal de salida en las últimas 24 horas")
            }
        }
    }
}

private struct WeeklySection: View {
    var weekly: Snapshot.Weekly

    var body: some View {
        DashboardSection("Boletín semanal", footer: "MITECO, \(Format.dayMonth(weekly.day)). Es otra medición y no coincide con el dato en tiempo real.") {
            LabeledContent("Agua embalsada", value: "\(Format.hm3(weekly.volumeHm3, decimals: 0)) (\(Format.percent(weekly.percent)))")
            LabeledContent("Variación semanal", value: "\(Format.signed(weekly.changeHm3, decimals: 0)) hm³")
            LabeledContent("Capacidad", value: Format.hm3(weekly.capacityHm3, decimals: 0))
            LabeledContent("Misma semana del año pasado", value: weekly.lastYearHm3.map { Format.hm3($0, decimals: 0) } ?? "Sin dato")
            LabeledContent("Media de 10 años", value: weekly.tenYearAvgHm3.map { Format.hm3($0) } ?? "Sin dato")
        }
    }
}

private struct WeatherSection: View {
    var weather: Snapshot.Weather

    var body: some View {
        DashboardSection("Tiempo en la presa", footer: "SAIH Tajo, \(Format.dayMonthHour(weather.observedAt)).") {
            WeatherRow("Temperatura", symbol: "thermometer.medium", value: Format.optional(weather.temperatureC, unit: "°C"))
            WeatherRow("Viento", symbol: "wind", value: windText)
            WeatherRow("Humedad", symbol: "humidity", value: Format.optional(weather.humidityPct, decimals: 0, unit: "%"))
            WeatherRow("Presión", symbol: "gauge.with.dots.needle.33percent", value: Format.optional(weather.pressureHpa, decimals: 0, unit: "hPa"))
            WeatherRow("Radiación solar", symbol: "sun.max", value: Format.optional(weather.solarWm2, decimals: 0, unit: "W/m²"))
            WeatherRow("Lluvia en 1 h", symbol: "cloud.rain", value: Format.optional(weather.rain1hMm, unit: "mm"))
            WeatherRow("Lluvia en 24 h", symbol: "cloud.heavyrain", value: Format.optional(weather.rain24hMm, unit: "mm"))
        }
    }

    private var windText: String {
        let speed = Format.optional(weather.windMs, unit: "m/s")
        guard weather.windMs != nil, let direction = weather.windDirectionDeg else { return speed }
        return "\(speed) \(Format.compass(direction))"
    }
}

private struct WeatherRow: View {
    var title: String
    var symbol: String
    var value: String

    init(_ title: String, symbol: String, value: String) {
        self.title = title
        self.symbol = symbol
        self.value = value
    }

    var body: some View {
        LabeledContent {
            Text(value)
        } label: {
            Label(title, systemImage: symbol)
        }
    }
}

private struct AlbercheSection: View {
    var snapshot: Snapshot

    var body: some View {
        let upstream = snapshot.neighbours.filter { $0.position == .upstream }
        let downstream = snapshot.neighbours.filter { $0.position == .downstream }
        DashboardSection("Río Alberche", footer: "De aguas arriba a aguas abajo.") {
            ForEach(upstream) { ChainRow(name: $0.name, percent: $0.percent, volume: $0.volumeHm3, isCurrent: false) }
            ChainRow(name: snapshot.reservoir.name, percent: snapshot.live.percent, volume: snapshot.live.volumeHm3, isCurrent: true)
            ForEach(downstream) { ChainRow(name: $0.name, percent: $0.percent, volume: $0.volumeHm3, isCurrent: false) }
        }

        if !snapshot.rainGauges.isEmpty {
            DashboardSection("Lluvia en la cuenca, 24 h", footer: "Pluviómetros del SAIH Tajo en la cuenca del Alberche.") {
                ForEach(snapshot.rainGauges) { gauge in
                    LabeledContent(gauge.name, value: Format.optional(gauge.rain24hMm, unit: "mm"))
                }
            }
        }
    }
}

private struct ChainRow: View {
    var name: String
    var percent: Double
    var volume: Double
    var isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Spacer()
                Text("\(Format.percent(percent)) · \(Format.hm3(volume))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Gauge(value: percent, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Palette.waterTop)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

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
