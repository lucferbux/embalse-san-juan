import EmbalseKit
import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class ReservoirModel {
    enum State {
        case loading
        case loaded(Snapshot, SnapshotRepository.Origin)
        case failed
    }

    private(set) var state: State = .loading
    private(set) var lastAttempt: Date?

    private let repository = SnapshotRepository()

    /// New data arrives hourly, so reopening the app more often than this needs no request.
    private static let minimumRefreshInterval: TimeInterval = 15 * 60

    init() {
        if let cached = repository.cached() {
            state = .loaded(cached, .cache)
        }
    }

    func refresh(force: Bool = false) async {
        if !force, let lastAttempt, Date.now.timeIntervalSince(lastAttempt) < Self.minimumRefreshInterval {
            return
        }
        lastAttempt = .now
        let previous = repository.cached()?.generatedAt
        do {
            let result = try await repository.load()
            state = .loaded(result.snapshot, result.origin)
            if result.snapshot.generatedAt != previous {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            if case .loaded = state { return }
            state = .failed
        }
    }
}
