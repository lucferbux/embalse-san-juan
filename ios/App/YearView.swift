import Charts
import EmbalseKit
import SwiftUI

/// "Este año": the MITECO bulletin, this year against last year and the 10-year average, the history, and AEMET's
/// forecast. SAIH and MITECO are never on one chart.
struct YearView: View {
    var snapshot: Snapshot
    var history: HistoryModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            content
                .padding(horizontalSizeClass == .regular ? 24 : 16)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Este año")
        .task { await history.load(.sanJuan) }
    }

    @ViewBuilder private var content: some View {
        let comparison = history.history(.sanJuan).flatMap(YearComparison.init)
        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 16) {
                    MitecoPanel(weekly: snapshot.weekly)
                    comparisonPanel(comparison)
                }
                VStack(spacing: 16) {
                    HistoryPanel(reservoir: .sanJuan, capacity: snapshot.weekly.capacityHm3, today: snapshot.reading(of: .sanJuan), history: history)
                    if let forecast = snapshot.forecast { ForecastStrip(forecast: forecast).panel() }
                }
            }
        } else {
            VStack(spacing: 16) {
                MitecoPanel(weekly: snapshot.weekly)
                comparisonPanel(comparison)
                if let forecast = snapshot.forecast { ForecastStrip(forecast: forecast).panel() }
                HistoryPanel(reservoir: .sanJuan, capacity: snapshot.weekly.capacityHm3, today: snapshot.reading(of: .sanJuan), history: history)
            }
        }
    }

    @ViewBuilder
    private func comparisonPanel(_ comparison: YearComparison?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle("Este año, el pasado y la media", source: Format.mitecoWeek(snapshot.weekly.day))
            if let comparison {
                YearComparisonChart.Legend()
                YearComparisonChart(comparison: comparison).frame(height: 240)
                Text("Cada línea es el dato semanal de MITECO. La media necesita los 10 años anteriores completos.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LoadingRow(state: history.state(.sanJuan)) { Task { await history.load(.sanJuan) } }
            }
        }
        .panel()
    }
}

/// A reservoir's history: 1 and 5 years from SAIH's daily values, since 1988 from MITECO's weekly ones. The period's
/// minimum, maximum and mean include today, so today can never fall outside them.
struct HistoryPanel: View {
    var reservoir: ReservoirID
    var capacity: Double
    var today: ReservoirReading?
    var history: HistoryModel

    enum Range: CaseIterable, Identifiable {
        case oneYear, fiveYears, all
        var id: Self { self }
        var title: LocalizedStringKey {
            switch self {
            case .oneYear: "1 año"
            case .fiveYears: "5 años"
            case .all: "Desde 1988"
            }
        }
    }

    struct Point: Identifiable {
        var date: Date
        var volume: Double
        /// MITECO lists the capacity with each week, and it has been revised: 148 hm³ in 1988, 138 hm³ today.
        var capacity: Double?
        var id: Date { date }
    }

    @State private var range: Range = Self.initialRange

    private static var initialRange: Range {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "HistoryRange") == "all" { return .all }
        #endif
        return .oneYear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle("Histórico")
            Picker("Periodo", selection: $range) {
                ForEach(Range.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if let history = history.history(reservoir) {
                let points = points(in: history)
                chart(points)
                Text(range == .all ? "Boletín Hidrológico de MITECO, dato semanal." : "SAIH Tajo, último valor de cada día, hasta hoy.")
                    .font(.caption).foregroundStyle(.secondary)
                statistics(points)
            } else {
                LoadingRow(state: history.state(reservoir)) { Task { await history.load(reservoir) } }
            }
        }
        .panel()
        .task { await history.load(reservoir) }
    }

    private func chart(_ points: [Point]) -> some View {
        Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Fecha", point.date), y: .value("Volumen", point.volume))
                    .foregroundStyle(LinearGradient(colors: [YearComparisonChart.thisYearColor.opacity(0.3), YearComparisonChart.thisYearColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Fecha", point.date), y: .value("Volumen", point.volume))
                    .foregroundStyle(YearComparisonChart.thisYearColor)
                    .lineStyle(StrokeStyle(lineWidth: range == .all ? 1 : 1.5))
            }
            if range == .all {
                ForEach(points) { point in
                    LineMark(x: .value("Fecha", point.date), y: .value("Capacidad", point.capacity ?? capacity), series: .value("Serie", "capacity"))
                        .foregroundStyle(.secondary)
                        .interpolationMethod(.stepEnd)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            } else {
                RuleMark(y: .value("Capacidad", capacity))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Capacidad \(Format.hm3(capacity, .mitecoVolume))").font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: 0...(max(points.compactMap(\.capacity).max() ?? capacity, points.map(\.volume).max() ?? 0) * 1.1))
        .chartYAxisLabel("hm³")
        .frame(height: 260)
        .accessibilityLabel(Text("Evolución del volumen"))
    }

    @ViewBuilder
    private func statistics(_ points: [Point]) -> some View {
        if let low = points.min(by: { $0.volume < $1.volume }), let high = points.max(by: { $0.volume < $1.volume }) {
            ValueRow("Mínimo", value: "\(Format.hm3(low.volume)), \(Format.monthYear(low.date))")
            ValueRow("Máximo", value: "\(Format.hm3(high.volume)), \(Format.monthYear(high.date))")
            ValueRow("Media", value: Format.hm3(points.map(\.volume).reduce(0, +) / Double(points.count)))
            let capacities = points.compactMap(\.capacity)
            if let first = capacities.first, let last = capacities.last, first != last {
                Text("La capacidad oficial ha cambiado: \(Format.hm3(first, .mitecoVolume)) al principio del periodo, \(Format.hm3(last, .mitecoVolume)) hoy.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Daily SAIH points end with today's reading, so the chart and the statistics always reach today.
    private func points(in history: History) -> [Point] {
        switch range {
        case .all:
            return history.weekly.map { Point(date: $0.date, volume: $0.volumeHm3, capacity: $0.capacityHm3) }
        case .fiveYears, .oneYear:
            var daily = history.daily.map { Point(date: $0.date, volume: $0.volumeHm3) }
            if range == .oneYear { daily = Array(daily.suffix(365)) }
            if let today, today.observedAt > (daily.last?.date ?? .distantPast) {
                daily.append(Point(date: today.observedAt, volume: today.volumeHm3))
            }
            return daily
        }
    }
}

struct LoadingRow: View {
    var state: HistoryModel.State
    var retry: () -> Void

    var body: some View {
        if state == .failed {
            HStack {
                Label("No se ha podido cargar", systemImage: "wifi.slash").foregroundStyle(.secondary)
                Spacer()
                Button("Reintentar", action: retry)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
        }
    }
}
