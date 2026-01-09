import SwiftUI
import EventKit

struct EventDetailView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let event: CalendarEvent
    var onClose: () -> Void
    var onDelete: () -> Void // Callback for deletion
    
    @State private var showEditSheet = false
    @StateObject private var routeViewModel = RouteViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
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
            .background(Color(nsColor: .controlBackgroundColor))
            .sheet(isPresented: $showEditSheet) {
                AddEventView(
                    viewModel: viewModel,
                    isPresented: $showEditSheet,
                    editingEvent: event
                )
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Title & Time
                    VStack(alignment: .leading, spacing: 8) {
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
                    
                    Divider()
                    
                    // Details List
                    VStack(spacing: 16) {
                        // Location
                        if let location = event.location, !location.isEmpty {
                            DetailRow(icon: "mappin.and.ellipse", text: location)
                            
                            // Route Information
                            if let coordinate = event.locationCoordinate {
                                routeInfoView(for: coordinate)
                            }
                        }
                        
                        // Calendar Name (We need to look this up, but for now we might skip or just show color)
                        // Note: CalendarEvent doesn't store calendar name directly yet, but we have ID.
                        // Ideally we'd look it up from ViewModel, but let's keep it simple.
                        
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
                .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            // Calculate route if event has location
            if let coordinate = event.locationCoordinate {
                Task {
                    await routeViewModel.calculateRoute(to: coordinate)
                }
            }
        }
    }
    
    // MARK: - Route Info View
    @ViewBuilder
    private func routeInfoView(for coordinate: LocationCoordinate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if routeViewModel.isCalculating {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20)
                    Text("計算路線中...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 32)
            } else if let error = routeViewModel.error {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .frame(width: 20)
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 32)
            } else if let multiRoute = routeViewModel.routeInfo {
                // 交通資訊
                VStack(alignment: .leading, spacing: 8) {
                    // 距離
                    if let route = multiRoute.recommendedRoute {
                        HStack(spacing: 12) {
                            Image(systemName: "ruler")
                                .frame(width: 20)
                                .foregroundColor(.secondary)
                            Text(route.distanceText)
                                .font(.system(size: 13))
                        }
                        .padding(.leading, 32)
                    }
                    
                    // 各種交通方式的時間
                    HStack(spacing: 16) {
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
                    .padding(.leading, 32)
                    
                    // 建議出發時間（只在非全天事件顯示）
                    if !event.isAllDay, let eventTime = event.time,
                       let route = multiRoute.recommendedRoute {
                        Divider()
                            .padding(.leading, 32)
                        
                        let departureTimeText = route.suggestedDepartureTimeText(for: eventTime)
                        let (shouldDepart, minutesUntil) = route.departureStatus(for: eventTime)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .frame(width: 20)
                                    .foregroundColor(.blue)
                                Text("建議出發時間：\(departureTimeText)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                            }
                            .padding(.leading, 32)
                            
                            // 出發提醒
                            if shouldDepart {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .frame(width: 20)
                                        .foregroundColor(minutesUntil <= 5 ? .red : .orange)
                                    
                                    if minutesUntil <= 0 {
                                        Text("該出發了！")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.red)
                                    } else {
                                        Text("還有 \(minutesUntil) 分鐘該出發了！")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(minutesUntil <= 5 ? .red : .orange)
                                    }
                                }
                                .padding(.leading, 32)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func transportTimeView(route: RouteInfo) -> some View {
        HStack(spacing: 4) {
            Image(systemName: route.transportIcon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(route.travelTimeText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
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

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
