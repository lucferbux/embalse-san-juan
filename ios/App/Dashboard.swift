import SwiftUI

/// Where a fold can divide the dashboard: iPhone Duo's inner display folds down the middle.
struct FoldGeometry: Equatable {
    var width: CGFloat = 0
    /// Where a side-by-side fold is, in the view's own coordinates, even while the display lies flat.
    var center: CGFloat?
    /// Horizontal span to keep clear while the fold actually divides the view.
    var keepClear: ClosedRange<CGFloat>?

    init() {}

    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        if #available(iOS 27.1, *) {
            let isSideBySide = { (frame: CGRect) in frame.height > frame.width }
            center = proxy.reservedRegions(kind: .division, options: .includeInactive)
                .first { isSideBySide($0.frame) }?.frame.midX
            if let fold = proxy.reservedRegions(kind: .division).first(where: { $0.isActive && isSideBySide($0.frame) }) {
                keepClear = (fold.frame.minX - fold.margins.leading)...(fold.frame.maxX + fold.margins.trailing)
            }
        }
    }
}
