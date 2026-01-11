import SwiftUI
import MapKit

/// 事件地點詳情視圖
/// 支援三種狀態：hidden（隱藏）、compact（350px）、expanded（500px）
struct EventLocationDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: CalendarViewModel
    let event: CalendarEvent
    let routeInfo: MultiRouteInfo?
    var onClose: () -> Void
    var onDelete: () -> Void
    
    @State private var mapState: MapState = .hidden
    @Binding var popoverWidth: CGFloat 
    
    enum MapState {
        case hidden    // 不顯示地圖
        case compact   // 350px 顯示地圖
        case expanded  // 500px 放大地圖
    }
    @State private var showEditSheet = false // 新增編輯 sheet 狀態
    @AppStorage("isPinnedToDesktop") private var isPinnedToDesktop: Bool = false
    
    var body: some View {
        mainContent
            .frame(width: popoverWidth) // Frame constraint
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: popoverWidth)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // Main Content definition
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                titleSection
                Divider()
                detailsSection
                
                if event.location != nil || event.locationCoordinate != nil {
                    locationSection
                }
            }
            .padding(20)
            
            // Map Section (Standard Vertical Stack)
            if mapState != .hidden {
                mapSection
                    .padding(.top, 5)
            }
            
            // In Desktop mode, we push content to top
            if isPinnedToDesktop {
                Spacer(minLength: 0)
            }
        }
    }
    
    // ...
    
    // MARK: - Map Section Refactor (Revert to Stack)
    @ViewBuilder
    private var mapSection: some View {
        if let multiRoute = routeInfo, let route = multiRoute.recommendedRoute {
            VStack(spacing: 0) {
                 // 1. Map
                 ZStack(alignment: .topTrailing) {
                    MapSnapshotView(
                        route: route.route,
                        size: CGSize(
                            width: mapState == .expanded ? 500 : 350,
                            height: mapState == .expanded ? 350 : 250
                        )
                    )
                    
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
                
                // 2. Info Card (Stacked BELOW map, no overlap)
                mapInfoCard(multiRoute: multiRoute)
                    .padding(16)
                    // Remove the background if we want clean look, or keep it.
                    // Since it's white-on-white, maybe divider?
                    // But mapInfoCard has its own background logic? 
                    // Let's rely on mapInfoCard's internal styling, but standard vertical flow.
            }
        }
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
            
            HStack(spacing: 12) {
                // 編輯按鈕
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                // 刪除按鈕
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
        .sheet(isPresented: $showEditSheet) {
            AddEventView(
                viewModel: viewModel,
                isPresented: $showEditSheet,
                editingEvent: event
            )
        }
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
        .fixedSize(horizontal: false, vertical: true) // Force it to fit content height
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
            if let cleanNotes = event.cleanNotes, !cleanNotes.isEmpty {
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
                    
                    Text(cleanNotes)
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
            
            // 路線資訊摘要（只在有路線資訊時顯示）
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
            
            // 展開地圖按鈕（只在有座標時顯示）
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
            } else if mapState == .hidden && event.location != nil {
                // 有地點但沒有座標時，顯示提示
                Text("⚠️ 請重新選擇地點以啟用地圖功能")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .padding(.vertical, 8)
            }
        }
    }
    
    
    // MARK: - Map Info Card
    @ViewBuilder
    private func mapInfoCard(multiRoute: MultiRouteInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 第一排：交通資訊（在 500px 下更開闊）
            if let route = multiRoute.recommendedRoute {
                HStack(spacing: mapState == .expanded ? 32 : 16) {
                    // 距離
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(route.distanceText)
                            .font(.system(size: 13, weight: .medium))
                    }
                    
                    // 各種交通方式
                    HStack(spacing: mapState == .expanded ? 20 : 12) {
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
                    
                    if mapState == .expanded {
                        Spacer()
                    }
                }
            }
            
            // 第二排：建議時間與提醒
            HStack(spacing: 16) {
                if !event.isAllDay, let eventTime = event.time,
                   let route = multiRoute.recommendedRoute {
                    let departureTimeText = route.suggestedDepartureTimeText(for: eventTime)
                    let (shouldDepart, minutesUntil) = route.departureStatus(for: eventTime)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue.opacity(0.8))
                        Text("建議出發：\(departureTimeText)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    
                    if shouldDepart {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text(minutesUntil <= 0 ? "該出發了！" : "剩餘 \(minutesUntil) 分鐘")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((minutesUntil <= 5 ? Color.red : Color.orange).opacity(0.1))
                        .foregroundColor(minutesUntil <= 5 ? .red : .orange)
                        .cornerRadius(6)
                    }
                }
                
                if mapState == .expanded {
                    Spacer()
                }
            }
            
            // 第三排：按鈕
            HStack(spacing: 12) {
                Button(action: openInAppleMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 11))
                        Text("Apple Maps")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: openInGoogleMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 11))
                        Text("Google Maps")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if mapState == .expanded {
                    Spacer()
                }
            }
        }
        .padding(16) // Content internal padding
        .background(
            // Card background styling
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        // No external padding here needed, parent stack handles it or we do it here.
        // For VStack flow, we usually want horizontal padding if it's full width
        // But in mapSection we applied .padding(16) to the card.
        // So here we should just contain the card visuals.
    }
    
    // ... inside mapSection ...
    // Note: I will modify mapSection spacer in a separate hunk or manually verify
    
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
