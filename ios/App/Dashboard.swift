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

/// Two columns, with the fold always in the gap between them: on iPhone Duo the columns are measured
/// from the fold, because its side bars make the safe area off-centre. While the device is half open
/// the gap widens to cover the fold. Narrow regular widths, such as iPad splits, get one column.
struct DashboardColumns<Leading: View, Trailing: View>: View {
    var fold: FoldGeometry
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    private static var margin: CGFloat { 20 }
    private static var minimumTwoColumnWidth: CGFloat { 640 }
    private static var maximumWidth: CGFloat { 1200 }

    var body: some View {
        if fold.width < Self.minimumTwoColumnWidth {
            VStack(spacing: 22) {
                leading
                trailing
            }
            .padding(Self.margin)
        } else if let center = fold.center {
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: 22) { leading }
                    .frame(width: max(0, center - gap / 2 - Self.margin))
                VStack(spacing: 22) { trailing }
                    .frame(width: max(0, fold.width - center - gap / 2 - Self.margin))
            }
            .padding(Self.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: 22) { leading }
                    .frame(maxWidth: .infinity)
                VStack(spacing: 22) { trailing }
                    .frame(maxWidth: .infinity)
            }
            .padding(Self.margin)
            .frame(maxWidth: fold.keepClear == nil ? Self.maximumWidth : .infinity)
            .frame(maxWidth: .infinity)
        }
    }

    private var gap: CGFloat {
        guard let clear = fold.keepClear else { return Self.margin }
        return max(Self.margin, clear.upperBound - clear.lowerBound)
    }
}

/// How sections draw themselves: as list sections on compact widths, as cards in the dashboard.
enum DashboardStyle {
    case list, cards
}

extension EnvironmentValues {
    @Entry var dashboardStyle: DashboardStyle = .list
}

struct DashboardSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content
    @Environment(\.dashboardStyle) private var style

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        switch style {
        case .list:
            Section {
                content
            } header: {
                if let title { Text(title) }
            } footer: {
                if let footer { Text(footer) }
            }
        case .cards:
            VStack(alignment: .leading, spacing: 8) {
                if let title {
                    Text(title)
                        .font(.headline)
                        .padding(.horizontal, 16)
                }
                VStack(spacing: 0) {
                    Group(subviews: content) { rows in
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            row
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                            if index < rows.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 26, style: .continuous))
                if let footer {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}
