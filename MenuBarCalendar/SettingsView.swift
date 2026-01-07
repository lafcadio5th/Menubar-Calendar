import SwiftUI
import ServiceManagement

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("startWeekOnMonday") private var startWeekOnMonday = false
    @AppStorage("showLunarCalendar") private var showLunarCalendar = false
    @AppStorage("defaultReminderTime") private var defaultReminderTime = 15
    @AppStorage("menuBarFormat") private var menuBarFormat = MenuBarFormat.dateAndDay
    
    @State private var launchAtLogin = false
    
    var body: some View {
        TabView {
            GeneralSettingsTab(launchAtLogin: $launchAtLogin, menuBarFormat: $menuBarFormat)
                .tabItem { Label("一般", systemImage: "gear") }
            
            CalendarSettingsTab(
                showWeekNumbers: $showWeekNumbers,
                startWeekOnMonday: $startWeekOnMonday,
                showLunarCalendar: $showLunarCalendar
            )
            .tabItem { Label("日曆", systemImage: "calendar") }
            
            NotificationSettingsTab(defaultReminderTime: $defaultReminderTime)
                .tabItem { Label("通知", systemImage: "bell") }
            
            AboutTab()
                .tabItem { Label("關於", systemImage: "info.circle") }
        }
        .frame(width: 400, height: 280)
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
    
    var body: some View {
        Form {
            Section {
                Toggle("登入時自動啟動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
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
    
    var body: some View {
        Form {
            Section {
                Toggle("顯示週數", isOn: $showWeekNumbers)
                Toggle("週一為每週第一天", isOn: $startWeekOnMonday)
                Toggle("顯示農曆", isOn: $showLunarCalendar)
            }
        }
        .formStyle(.grouped)
        .padding()
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("Menu Bar 行事曆")
                .font(.system(size: 18, weight: .semibold))
            
            Text("版本 1.0.0")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("一個簡潔優雅的 macOS 選單列行事曆應用程式")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(24)
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
