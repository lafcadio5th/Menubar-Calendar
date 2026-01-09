import SwiftUI
import MapKit

/// 事件地點詳情視圖
/// 支援三種狀態：hidden（隱藏）、compact（350px）、expanded（500px）
struct EventLocationDetailView: View {
    let event: CalendarEvent
    let routeInfo: MultiRouteInfo?
    var onClose: () -> Void
    var onDelete: () -> Void
    
    @State private var mapState: MapState = .hidden
    @State private var popoverWidth: CGFloat = 350
    
    enum MapState {
        case hidden    // 不顯示地圖
        case compact   // 350px 顯示地圖
        case expanded  // 500px 放大地圖
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title & Time
                    titleSection
                    
                    Divider()
                    
                    // Details
                    detailsSection
                    
                    // 地點資訊（如果有）
                    if event.location != nil || event.locationCoordinate != nil {
                        locationSection
                    }
                }
                .padding(20)
            }
            
            // 地圖區域（如果展開）
            if mapState != .hidden {
                mapSection
            }
        }
        .frame(width: popoverWidth)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    // MARK: - Header
    @ViewBuilder
    private var header: some View {
        HStack {
            // 左側按鈕
            Button(action: handleHeaderButtonAction) {
                Image(systemName: headerButtonIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(event.isAllDay ? "全天事件" : "事件詳情")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            // 刪除按鈕
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var headerButtonIcon: String {
        switch mapState {
        case .hidden, .compact:
            return "xmark.circle.fill"  // 關閉事件
        case .expanded:
            return "arrow.left"  // 縮小地圖
        }
    }
    
    private func handleHeaderButtonAction() {
        switch mapState {
        case .hidden, .compact:
            onClose()  // 關閉事件詳情
        case .expanded:
            collapseMap()  // 縮小地圖
        }
    }
    
    // MARK: - Title Section
    @ViewBuilder
    private var titleSection: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 20, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formatEventTime())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Details Section
    @ViewBuilder
    private var detailsSection: some View {
        VStack(spacing: 16) {
            // URL
            if let url = event.url {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "link")
                        .frame(width: 20)
                        .foregroundColor(.secondary)
                    Link(url.absoluteString, destination: url)
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            
            // Notes
            if let notes = event.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.alignleft")
                            .frame(width: 20)
                            .foregroundColor(.secondary)
                        Text("備註")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .padding(.leading, 32)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    // MARK: - Location Section
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 地點名稱
            if let location = event.location, !location.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .frame(width: 20)
                        .foregroundColor(.secondary)
                    Text(location)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
            
            // 路線資訊摘要
            if let multiRoute = routeInfo, let route = multiRoute.recommendedRoute {
                VStack(alignment: .leading, spacing: 8) {
                    // 距離
                    HStack(spacing: 12) {
                        Image(systemName: "ruler")
                            .frame(width: 20)
                            .foregroundColor(.secondary)
                        Text(route.distanceText)
                            .font(.system(size: 13))
                    }
                    .padding(.leading, 32)
                    
                    // 交通時間
                    HStack(spacing: 16) {
                        if let driving = multiRoute.driving {
                            transportTimeView(route: driving)
                        }
                        if let walking = multiRoute.walking {
                            transportTimeView(route: walking)
                        }
                    }
                    .padding(.leading, 32)
                }
            }
            
            // 展開地圖按鈕
            if mapState == .hidden && event.locationCoordinate != nil {
                Button(action: showMap) {
                    HStack {
                        Spacer()
                        Text("點擊查看地圖")
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Map Section
    @ViewBuilder
    private var mapSection: some View {
        if let multiRoute = routeInfo, let route = multiRoute.recommendedRoute {
            ZStack(alignment: .topTrailing) {
                // 地圖
                MapSnapshotView(
                    route: route.route,
                    size: CGSize(
                        width: popoverWidth,
                        height: mapState == .expanded ? 350 : 250
                    )
                )
                
                // 放大按鈕（僅在 compact 狀態顯示）
                if mapState == .compact {
                    Button(action: expandMap) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
            
            // 詳細路線資訊（浮動卡片）
            mapInfoCard(multiRoute: multiRoute)
        }
    }
    
    // MARK: - Map Info Card
    @ViewBuilder
    private func mapInfoCard(multiRoute: MultiRouteInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 交通資訊
            if let route = multiRoute.recommendedRoute {
                HStack(spacing: mapState == .expanded ? 24 : 16) {
                    // 距離
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(route.distanceText)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    
                    // 各種交通方式
                    if let driving = multiRoute.driving {
                        transportTimeView(route: driving)
                    }
                    if let walking = multiRoute.walking {
                        transportTimeView(route: walking)
                    }
                    if let transit = multiRoute.transit {
                        transportTimeView(route: transit)
                    }
                }
            }
            
            // 建議出發時間
            if !event.isAllDay, let eventTime = event.time,
               let route = multiRoute.recommendedRoute {
                let departureTimeText = route.suggestedDepartureTimeText(for: eventTime)
                let (shouldDepart, minutesUntil) = route.departureStatus(for: eventTime)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("建議出發時間：\(departureTimeText)")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                
                // 出發警告
                if shouldDepart {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(minutesUntil <= 5 ? .red : .orange)
                        
                        if minutesUntil <= 0 {
                            Text("該出發了！")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        } else {
                            Text("還有 \(minutesUntil) 分鐘該出發了！")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(minutesUntil <= 5 ? .red : .orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((minutesUntil <= 5 ? Color.red : Color.orange).opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // 打開地圖按鈕
            HStack(spacing: 12) {
                Button(action: openInAppleMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 11))
                        Text("在 Apple Maps 中打開")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: openInGoogleMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 11))
                        Text("在 Google Maps 中打開")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(16)
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func transportTimeView(route: RouteInfo) -> some View {
        HStack(spacing: 4) {
            Image(systemName: route.transportIcon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(route.travelTimeText)
                .font(.system(size: 13))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Actions
    private func showMap() {
        withAnimation(.easeInOut(duration: 0.3)) {
            mapState = .compact
        }
    }
    
    private func expandMap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            mapState = .expanded
            popoverWidth = 500
        }
    }
    
    private func collapseMap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            mapState = .compact
            popoverWidth = 350
        }
    }
    
    private func openInAppleMaps() {
        guard let coordinate = event.locationCoordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )))
        mapItem.name = event.location
        mapItem.openInMaps(launchOptions: nil)
    }
    
    private func openInGoogleMaps() {
        guard let coordinate = event.locationCoordinate else { return }
        let urlString = "https://www.google.com/maps/search/?api=1&query=\(coordinate.latitude),\(coordinate.longitude)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Helpers
    private func formatEventTime() -> String {
        let dateDateFormatter = DateFormatter()
        dateDateFormatter.dateFormat = "M月d日 EEEE"
        let dateString = dateDateFormatter.string(from: event.date)
        
        if event.isAllDay {
            return "\(dateString) • 全天"
        } else {
            return "\(dateString) • \(event.timeString)"
        }
    }
}
