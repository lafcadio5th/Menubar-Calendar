import SwiftUI
import AppKit

@main
struct MacMenuBarCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ App 已啟動！")
        
        // 建立 Status Item (Menu Bar 圖標)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("✅ StatusItem 已建立：\(statusItem != nil)")
        
        // 設定按鈕
        if let button = statusItem.button {
            print("✅ Button 已取得")
            
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "行事曆")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
            
            // 添加右鍵選單
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // 更新選單列標題
            updateMenuBarTitle()
            
            // 每分鐘更新一次時間
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            
            // 監聽設定變更
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateMenuBarTitle),
                name: UserDefaults.didChangeNotification,
                object: nil
            )
            
            print("✅ Button 設定完成，標題：\(button.title)")
        } else {
            print("❌ 無法取得 Button")
        }
        
        // 建立選單
        setupMenu()
        
        // 建立 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 650)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: CalendarPopoverView())
        
        print("✅ Popover 已建立")
    }
    
    @objc func updateMenuBarTitle() {
        guard let button = statusItem.button else { return }
        
        // 讀取用戶設定的格式
        let formatRawValue = UserDefaults.standard.string(forKey: "menuBarFormat") ?? "dateAndDay"
        let format = MenuBarFormat(rawValue: formatRawValue) ?? .dateAndDay
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        
        switch format {
        case .dateOnly:
            formatter.dateFormat = "M月d日"
        case .dateAndDay:
            formatter.dateFormat = "M月d日 EEE"
        case .full:
            formatter.dateFormat = "yyyy年M月d日 EEEE"
        }
        
        button.title = " " + formatter.string(from: Date())
    }
    
    func setupMenu() {
        menu = NSMenu()
        
        // 設定選項
        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 結束選項
        let quitItem = NSMenuItem(title: "結束 Menu Bar 行事曆", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func togglePopover() {
        print("🖱️ togglePopover 被呼叫")
        
        guard let button = statusItem.button else {
            print("❌ 無法取得 button")
            return
        }
        
        // 檢查是否為右鍵點擊
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                print("🖱️ 右鍵點擊 - 顯示選單")
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
                return
            }
        }
        
        // 左鍵點擊 - 切換 popover
        if popover.isShown {
            print("📕 關閉 Popover")
            popover.performClose(nil)
        } else {
            print("📖 開啟 Popover")
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

