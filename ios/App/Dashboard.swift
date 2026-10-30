import SwiftUI

/// Where a fold can divide the dashboard: iPhone Duo's inner display folds down the middle.
struct FoldGeometry: Equatable {
    var width: CGFloat = 0
    /// Horizontal span to keep clear while a fold divides the view side by side, in its own coordinates.
    var keepClear: ClosedRange<CGFloat>?

    init() {}

    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        if #available(iOS 27.1, *),
           let fold = proxy.reservedRegions(kind: .division).first(where: { $0.isActive && $0.frame.height > $0.frame.width }) {
            keepClear = (fold.frame.minX - fold.margins.leading)...(fold.frame.maxX + fold.margins.trailing)
        }
    }
}

/// Two equal columns, so the fold always falls in the gap between them. While the device is half
/// open the gap widens to cover it. Narrow regular widths, such as iPad splits, get one column.
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
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}
