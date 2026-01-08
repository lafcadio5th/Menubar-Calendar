import SwiftUI
import ServiceManagement
import EventKit

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("startWeekOnMonday") private var startWeekOnMonday = false
    @AppStorage("showLunarCalendar") private var showLunarCalendar = false
    @AppStorage("defaultReminderTime") private var defaultReminderTime = 15
    @AppStorage("menuBarFormat") private var menuBarFormat = MenuBarFormat.dateAndDay
    
    @State private var launchAtLogin = false
    
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .system }
    
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "一般"
        case calendar = "日曆"
        case notification = "通知"
        case integration = "整合"
        case about = "關於"
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 標題欄
            ZStack {
                Text("設定")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack {
                    Spacer()
                    Button(action: {
                        NSApplication.shared.keyWindow?.close()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // 分頁切換
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            // 內容區域
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(launchAtLogin: $launchAtLogin, menuBarFormat: $menuBarFormat)
                case .calendar:
                    CalendarSettingsTab(
                        showWeekNumbers: $showWeekNumbers,
                        startWeekOnMonday: $startWeekOnMonday,
                        showLunarCalendar: $showLunarCalendar
                    )
                case .notification:
                    NotificationSettingsTab(defaultReminderTime: $defaultReminderTime)
                case .integration:
                    IntegrationSettingsTab()
                case .about:
                    AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 500, height: 500) // Slightly adjusted frame
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(appTheme.colorScheme)
        .onAppear { checkLaunchAtLoginStatus() }
    }
    
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @Binding var launchAtLogin: Bool
    @Binding var menuBarFormat: MenuBarFormat
    
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    
    var body: some View {
        Form {
            Section {
                Toggle("登入時自動啟動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
            
            Section("外觀") {
                Picker("主題", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                // .pickerStyle(.segmented) // 移除 segmented 樣式，改用預設下拉選單，避免選項擠壓
            }
            
            Section("選單列顯示格式") {
                Picker("格式", selection: $menuBarFormat) {
                    ForEach(MenuBarFormat.allCases, id: \.self) { format in
                        Text(format.example).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("無法設定登入時啟動: \(error)")
            }
        }
    }
}

// MARK: - Calendar Settings Tab
struct CalendarSettingsTab: View {
    @Binding var showWeekNumbers: Bool
    @Binding var startWeekOnMonday: Bool
    @Binding var showLunarCalendar: Bool
    
    @ObservedObject private var eventKitService = EventKitService.shared
    // store hidden IDs (inverted logic)
    @State private var hiddenCalendarIDs: [String] = []
    
    @AppStorage("eventIndicatorColor") private var eventIndicatorColorHex = "#007AFF"
    @AppStorage("showFestiveEffects") private var showFestiveEffects = true
    @AppStorage("demoFestival") var demoFestivalRaw: String = Festival.none.rawValue
    
    var body: some View {
        Form {
            Section {
                Toggle("週一為每週第一天", isOn: $startWeekOnMonday)
                Toggle("顯示週數", isOn: $showWeekNumbers)
                Toggle("顯示農曆", isOn: $showLunarCalendar)
                Toggle("顯示節慶特效", isOn: $showFestiveEffects)
                
                if showFestiveEffects {
                    Picker("特效預覽", selection: $demoFestivalRaw) {
                        ForEach(Festival.allCases) { festival in
                            Text(festival.displayName).tag(festival.rawValue)
                        }
                    }
                }
                
                ColorPicker("有事件的日期顏色", selection: Binding(
                    get: { Color(hex: eventIndicatorColorHex) ?? .blue },
                    set: { eventIndicatorColorHex = $0.toHex() ?? "#007AFF" }
                ))
            }
            
            Section("顯示的行事曆") {
                if eventKitService.calendars.isEmpty {
                    VStack(alignment: .leading) {
                        Text("無可用的行事曆")
                            .foregroundColor(.secondary)
                        Text("請確認已授予行事曆存取權限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(eventKitService.calendars, id: \.calendarIdentifier) { calendar in
                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 8, height: 8)
                                    
                                    Text(calendar.title)
                                    
                                    Spacer()
                                    
                                    if !hiddenCalendarIDs.contains(calendar.calendarIdentifier) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleCalendar(calendar.calendarIdentifier)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.1))
                                        .opacity(hiddenCalendarIDs.contains(calendar.calendarIdentifier) ? 0 : 0.5)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            eventKitService.fetchCalendars()
            loadHiddenCalendars()
        }
    }
    
    private func loadHiddenCalendars() {
        hiddenCalendarIDs = UserDefaults.standard.stringArray(forKey: "hiddenCalendarIDs") ?? []
    }
    
    private func toggleCalendar(_ id: String) {
        if let index = hiddenCalendarIDs.firstIndex(of: id) {
            hiddenCalendarIDs.remove(at: index)
        } else {
            hiddenCalendarIDs.append(id)
        }
        // Save immediately
        UserDefaults.standard.set(hiddenCalendarIDs, forKey: "hiddenCalendarIDs")
    }
}

// MARK: - Notification Settings Tab
struct NotificationSettingsTab: View {
    @Binding var defaultReminderTime: Int
    
    var body: some View {
        Form {
            Section("預設提醒時間") {
                Picker("事件前提醒", selection: $defaultReminderTime) {
                    Text("無").tag(0)
                    Text("5 分鐘前").tag(5)
                    Text("10 分鐘前").tag(10)
                    Text("15 分鐘前").tag(15)
                    Text("30 分鐘前").tag(30)
                    Text("1 小時前").tag(60)
                    Text("1 天前").tag(1440)
                }
            }
            
            Section {
                Button("開啟系統通知設定") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab
struct AboutTab: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    var body: some View {
        VStack(spacing: 24) {
            // App Header
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock") // Changed icon slightly for freshness
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 100)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color(nsColor: .systemIndigo)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 4) {
                    Text("Menu Bar Calendar")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("版本 \(appVersion)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Text("一個簡潔優雅的 macOS 選單列行事曆，\n讓您的時間管理更加輕鬆愉快。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal)
            
            // Actions
            HStack(spacing: 16) {
                AboutLinkButton(title: "GitHub", icon: "star.fill", url: URL(string: "https://github.com/lafcadio5th/Menubar-Calendar")!)
                AboutLinkButton(title: "回報問題", icon: "ant.fill", url: URL(string: "https://github.com/lafcadio5th/Menubar-Calendar/issues")!)
                // AboutLinkButton(title: "聯絡作者", icon: "envelope.fill", url: URL(string: "mailto:kelvin@example.com")!)
            }
            
            Spacer()
            
            Text("© 2026 Kelvin Tan. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

struct AboutLinkButton: View {
    let title: String
    let icon: String
    let url: URL
    @State private var isHovering = false
    
    var body: some View {
        Link(destination: url) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(width: 80, height: 64)
            .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Integration Settings Tab
struct IntegrationSettingsTab: View {
    @AppStorage("todoistApiToken") private var todoistApiToken = ""
    @AppStorage("todoistRefreshInterval") private var todoistRefreshInterval = 0
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .none
    
    enum ConnectionStatus {
        case none
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Todoist").font(.headline)) {
                Text("輸入您的 API Token 以整合待辦事項。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("API Token", text: $todoistApiToken)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("測試連線") {
                        testConnection()
                    }
                    .disabled(todoistApiToken.isEmpty || isTestingConnection)
                    
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(height: 16)
                    }
                    
                    switch connectionStatus {
                    case .success:
                        Label("連線成功", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .failure(let message):
                        Label("連線失敗: \(message)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .help(message)
                    case .none:
                        EmptyView()
                    }
                }
            }
            
            Section(header: Text("自動更新")) {
                Picker("更新頻率", selection: $todoistRefreshInterval) {
                    Text("手動").tag(0)
                    Text("每 1 分鐘").tag(60)
                    Text("每 5 分鐘").tag(300)
                    Text("每 15 分鐘").tag(900)
                    Text("每 30 分鐘").tag(1800)
                    Text("每 1 小時").tag(3600)
                }
                .pickerStyle(.menu) // Dropdown style usually looks better for this
                
                Text(todoistRefreshInterval == 0 ? "僅在開啟或切換日期時更新。" : "將在背景自動更新任務列表。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                 Link("如何取得 API Token?", destination: URL(string: "https://todoist.com/prefs/integrations")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = .none
        
        let token = todoistApiToken
        guard !token.isEmpty else { return }
        
        // Simple API call to verify token (Fetch projects lightly)
        guard let url = URL(string: "https://api.todoist.com/rest/v2/projects") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isTestingConnection = false
                
                if let error = error {
                    connectionStatus = .failure(error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    connectionStatus = .success
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    connectionStatus = .failure("錯誤碼: \(code)")
                }
            }
        }.resume()
    }
}

// MARK: - Menu Bar Format
enum MenuBarFormat: String, CaseIterable {
    case dateOnly = "dateOnly"
    case dateAndDay = "dateAndDay"
    case full = "full"
    
    var example: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        
        switch self {
        case .dateOnly:
            formatter.dateFormat = "M月d日"
        case .dateAndDay:
            formatter.dateFormat = "M月d日 EEE"
        case .full:
            formatter.dateFormat = "yyyy年M月d日 EEEE"
        }
        return formatter.string(from: now)
    }
}
