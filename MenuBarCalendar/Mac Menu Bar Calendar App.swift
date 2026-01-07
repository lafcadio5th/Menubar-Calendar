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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ App 已啟動！")
        
        // 建立 Status Item (Menu Bar 圖標)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("✅ StatusItem 已建立：\(statusItem != nil)")
        
        // 設定按鈕
        if let button = statusItem.button {
            print("✅ Button 已取得")
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_TW")
            formatter.dateFormat = "M月d日 EEE"
            
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "行事曆")
            button.title = " " + formatter.string(from: Date())
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
            
            print("✅ Button 設定完成，標題：\(button.title)")
        } else {
            print("❌ 無法取得 Button")
        }
        
        // 建立 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 650)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: CalendarPopoverView())
        
        print("✅ Popover 已建立")
    }
    
    @objc func togglePopover() {
        print("🖱️ togglePopover 被呼叫")
        
        guard let button = statusItem.button else {
            print("❌ 無法取得 button")
            return
        }
        
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
