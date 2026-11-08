import Charts
import EmbalseKit
import SwiftUI

/// What a module opens: the full panel it summarises.
enum NowDetail: String, Hashable { case recent, outflow, weather, miteco }

/// The modules under the water card. Each one has a single source (SAIH, MITECO or AEMET) with its date, and most open
/// their full panel. Two columns on a phone, one at accessibility sizes.
struct Modules: View {
    var snapshot: Snapshot
    var columns: Int

    var body: some View {
        VStack(spacing: 12) {
            pair { outflow } _: { miteco }
            recent
            if let forecast = snapshot.forecast {
                ForecastStrip(forecast: forecast).moduleBackground()
            }
            pair { weather } _: { elevation }
            river
        }
    }

    @ViewBuilder
    private func pair<A: View, B: View>(@ViewBuilder _ first: () -> A, @ViewBuilder _ second: () -> B) -> some View {
        if columns >= 2 {
            Grid(horizontalSpacing: 12) {
                GridRow { first(); second() }
            }
        } else {
            first()
            second()
        }
    }

    private var saih: String { Format.saihSource(snapshot.live.observedAt) }

    private var outflow: some View {
        ModuleTile("Salida al río", symbol: "arrow.down.right.circle", source: saih, route: .detail(.outflow)) {
            Text(Format.optional(snapshot.live.outflowM3s, decimals: 2, unit: "m³/s")).figureFont(.title2)
            let readings = snapshot.recent.filter { $0.outflowM3s != nil }
            if readings.count > 1 {
                Chart(readings) { reading in
                    AreaMark(x: .value("Hora", reading.at), y: .value("Caudal", reading.outflowM3s ?? 0))
                        .foregroundStyle(YearComparisonChart.thisYearColor.opacity(0.18))
                        .interpolationMethod(.stepEnd)
                    LineMark(x: .value("Hora", reading.at), y: .value("Caudal", reading.outflowM3s ?? 0))
                        .foregroundStyle(YearComparisonChart.thisYearColor)
                        .interpolationMethod(.stepEnd)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...max(readings.compactMap(\.outflowM3s).max() ?? 1, 1))
                .frame(height: 40)
                .accessibilityHidden(true)
                if let peak = readings.max(by: { ($0.outflowM3s ?? 0) < ($1.outflowM3s ?? 0) }),
                   let value = peak.outflowM3s, value >= 2 * max(snapshot.live.outflowM3s ?? 0, 0.5) {
                    Text("Pico de \(Format.value(value, .flow, unit: "m³/s")) a las \(Format.hour(peak.at))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var miteco: some View {
        let weekly = snapshot.weekly
        return ModuleTile("Semanal", symbol: "calendar", source: Format.mitecoWeek(weekly.day), route: .detail(.miteco)) {
            Text(Format.percent(weekly.percent)).figureFont(.title2)
            Text("\(Format.hm3(weekly.volumeHm3, .mitecoVolume)) · \(Format.signed(weekly.changeHm3, decimals: 0)) en la semana")
                .font(.footnote).foregroundStyle(.secondary)
            if let average = weekly.tenYearAvgHm3 {
                Text("Media de 10 años: \(Format.hm3(average, .mitecoVolume))").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var recent: some View {
        ModuleTile("Últimas 24 horas", symbol: "clock.arrow.circlepath", source: saih, route: .detail(.recent)) {
            Label(Trend.sentence(snapshot.live.trend24hHm3), systemImage: Trend(change: snapshot.live.trend24hHm3).symbol)
                .font(.subheadline.weight(.semibold))
            RecentChart(readings: snapshot.recent).frame(height: 110)
        }
    }

    private var weather: some View {
        let weather = snapshot.weather
        return ModuleTile("En la presa", symbol: "thermometer.medium", source: Format.saihSource(weather.observedAt), route: .detail(.weather)) {
            Text(Format.optional(weather.temperatureC, decimals: 0, unit: "°C")).figureFont(.title2)
            Text("Humedad \(Format.optional(weather.humidityPct, decimals: 0, unit: "%"))").font(.footnote).foregroundStyle(.secondary)
            Text("Lluvia hoy \(Format.optional(weather.rain24hMm, unit: "mm"))").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var elevation: some View {
        ModuleTile("Cota", symbol: "ruler", source: saih, route: .detail(.recent)) {
            Text(Format.optional(snapshot.live.elevationM, decimals: 2, unit: "m")).figureFont(.title2)
            Text("Nivel \(Format.optional(snapshot.live.levelM, decimals: 2, unit: "m"))").font(.footnote).foregroundStyle(.secondary)
            Text("Trasvase \(Format.optional(snapshot.live.transferM3s, decimals: 2, unit: "m³/s"))").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var river: some View {
        ModuleTile("El río", symbol: "point.topleft.down.to.point.bottomright.curvepath", source: "SAIH Tajo", route: nil) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(snapshot.chain) { reading in
                    NavigationLink(value: Route.reservoir(reading.reservoir)) {
                        ReservoirTank(reading: reading, isCurrent: reading.reservoir == .sanJuan, tankHeight: 70)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// One module: a title with its symbol, the content, and the source at the bottom. Opens `route` when there is one.
struct ModuleTile<Content: View>: View {
    var title: LocalizedStringKey
    var symbol: String
    var source: String
    var route: Route?
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey, symbol: String, source: String, route: Route?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.source = source
        self.route = route
        self.content = content()
    }

    var body: some View {
        if let route {
            NavigationLink(value: route) { tile }.buttonStyle(.plain)
        } else {
            tile
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if route != nil { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary) }
            }
            content
            Spacer(minLength: 0)
            Text(source).font(.caption2).foregroundStyle(.secondary)
        }
        .moduleBackground()
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func moduleBackground() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 22, style: .continuous))
            .contentShape(.rect(cornerRadius: 22, style: .continuous))
    }
}

/// The full panel behind a module.
struct NowDetailView: View {
    var detail: NowDetail
    var snapshot: Snapshot

    var body: some View {
        ScrollView {
            Group {
                switch detail {
                case .recent: RealtimePanel(snapshot: snapshot)
                case .outflow: OutflowPanel(snapshot: snapshot)
                case .weather: WeatherPanel(weather: snapshot.weather)
                case .miteco: MitecoPanel(weekly: snapshot.weekly)
                }
            }
            .padding(16)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: LocalizedStringKey {
        switch detail {
        case .recent: "Últimas 24 horas"
        case .outflow: "Salida al río"
        case .weather: "En la presa"
        case .miteco: "Semanal · MITECO"
        }
    }
}
