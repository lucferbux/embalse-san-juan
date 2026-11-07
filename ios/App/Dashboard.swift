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

/// Columns of panels, with the fold always in the gap between them: on iPhone Duo the columns are measured from the
/// fold, because its side bars make the safe area off-centre, and while the device is half open the gap widens to
/// cover it. With a fold, or below 1000 pt, there are two columns (`middle` and `trailing` share the second); a wide
/// iPad gets three. Narrow regular widths, such as iPad splits, get one.
struct DashboardColumns<Leading: View, Middle: View, Trailing: View>: View {
    var fold: FoldGeometry
    var columns: Int
    @ViewBuilder var leading: Leading
    @ViewBuilder var middle: Middle
    @ViewBuilder var trailing: Trailing

    private static var margin: CGFloat { 20 }
    private static var minimumTwoColumnWidth: CGFloat { 640 }

    var body: some View {
        if fold.width < Self.minimumTwoColumnWidth {
            VStack(spacing: 16) { leading; middle; trailing }
                .padding(Self.margin)
        } else if let center = fold.center {
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: 16) { leading }
                    .frame(width: max(0, center - gap / 2 - Self.margin))
                VStack(spacing: 16) { middle; trailing }
                    .frame(width: max(0, fold.width - center - gap / 2 - Self.margin))
            }
            .padding(Self.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if columns >= 3 {
            HStack(alignment: .top, spacing: Self.margin) {
                VStack(spacing: 16) { leading }.frame(maxWidth: .infinity)
                VStack(spacing: 16) { middle }.frame(maxWidth: .infinity)
                VStack(spacing: 16) { trailing }.frame(maxWidth: .infinity)
            }
            .padding(Self.margin)
        } else {
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: 16) { leading }.frame(maxWidth: .infinity)
                VStack(spacing: 16) { middle; trailing }.frame(maxWidth: .infinity)
            }
            .padding(Self.margin)
        }
    }

    private var gap: CGFloat {
        guard let clear = fold.keepClear else { return Self.margin }
        return max(Self.margin, clear.upperBound - clear.lowerBound)
    }
}
