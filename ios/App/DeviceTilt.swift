import CoreMotion
import Observation

/// How far the device leans sideways, so the water's surface can stay level as the phone tilts. Kept small and
/// smoothed: the surface leans at most 2°, and never with Reduce Motion (NowView doesn't start it then).
@MainActor
@Observable
final class DeviceTilt {
    private(set) var angle: Double = 0
    private let manager = CMMotionManager()
    private static let limit = 2.0 * .pi / 180

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            // Counter-rotate against the roll, so the surface stays level, damped and capped.
            let target = max(-Self.limit, min(Self.limit, -gravity.x * 0.25))
            self.angle += (target - self.angle) * 0.15
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        angle = 0
    }
}
