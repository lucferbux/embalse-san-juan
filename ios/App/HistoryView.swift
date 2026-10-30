import Charts
import EmbalseKit
import SwiftUI

struct HistoryView: View {
    var weekly: Snapshot.Weekly

    private enum Range: String, CaseIterable, Identifiable {
        case oneYear = "1 año"
        case fiveYears = "5 años"
        case all = "Desde 1988"
        var id: Self { self }
    }

    private struct Point: Identifiable {
        var date: Date
        var volume: Double
        var id: Date { date }
    }

    private enum LoadState {
        case loading
        case loaded(History)
        case failed
    }

    @State private var range: Range = .oneYear
    @State private var state: LoadState = .loading

    var body: some View {
        List {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("No se ha podido cargar", systemImage: "wifi.slash")
                } actions: {
                    Button("Reintentar") {
                        Task { await load() }
                    }
                }
            case .loaded(let history):
                content(points(in: history))
            }
        }
        .navigationTitle("Histórico")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await FirestoreClient().fetchHistory())
        } catch {
            state = .failed
        }
    }

    @ViewBuilder
    private func content(_ points: [Point]) -> some View {
        Section {
            Picker("Periodo", selection: $range) {
                ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }

        Section {
            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Fecha", point.date), y: .value("Volumen", point.volume))
                        .foregroundStyle(LinearGradient(colors: [Palette.waterTop.opacity(0.35), Palette.waterTop.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Fecha", point.date), y: .value("Volumen", point.volume))
                        .foregroundStyle(Palette.waterTop)
                        .lineStyle(StrokeStyle(lineWidth: range == .all ? 1 : 1.5))
                }
                RuleMark(y: .value("Capacidad", weekly.capacityHm3))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Capacidad")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: 0...(max(weekly.capacityHm3, points.map(\.volume).max() ?? 0) * 1.1))
            .chartYAxisLabel("hm³")
            .frame(height: 280)
            .padding(.vertical, 8)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityLabel("Evolución del volumen del embalse")
        } footer: {
            Text(range == .all ? "Boletín Hidrológico de MITECO, dato semanal." : "SAIH Tajo, último valor de cada día.")
        }

        if let low = points.min(by: { $0.volume < $1.volume }),
           let high = points.max(by: { $0.volume < $1.volume }) {
            Section("En este periodo") {
                LabeledContent("Mínimo", value: "\(Format.hm3(low.volume)), \(low.date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "es_ES"))))")
                LabeledContent("Máximo", value: "\(Format.hm3(high.volume)), \(high.date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "es_ES"))))")
                LabeledContent("Media", value: Format.hm3(points.map(\.volume).reduce(0, +) / Double(points.count)))
            }
        }
    }

    private func points(in history: History) -> [Point] {
        switch range {
        case .all:
            return history.weekly.map { Point(date: $0.date, volume: $0.volumeHm3) }
        case .fiveYears:
            return history.daily.map { Point(date: $0.date, volume: $0.volumeHm3) }
        case .oneYear:
            return history.daily.suffix(365).map { Point(date: $0.date, volume: $0.volumeHm3) }
        }
    }
}
