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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var menu: NSMenu!
    var desktopWindowController: DesktopWindowController?
    var calendarViewModel = CalendarViewModel()
    
    @AppStorage("isPinnedToDesktop") private var isPinnedToDesktop: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ App 已啟動！")
        
        // 建立 Status Item (Menu Bar 圖標)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 設定按鈕
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "行事曆")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            updateMenuBarTitle()
            
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateMenuBarTitle),
                name: UserDefaults.didChangeNotification,
                object: nil
            )
        }
        
        // 建立選單
        setupMenu()
        
        // 建立 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 650)
        popover.behavior = .transient
        popover.animates = true
        
        // Use shared viewModel and provide a dummy DragState or handle it internally
        let contentView = CalendarPopoverView(
            viewModel: calendarViewModel,
            dragState: DesktopWindowController.DragState() 
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // 建立 Desktop Window Controller
        desktopWindowController = DesktopWindowController()
        
        // 如果原本就是釘選狀態，則顯示桌面組件
        if isPinnedToDesktop {
            desktopWindowController?.show()
        }
        
        // 監聽 isPinnedToDesktop 的變化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePinnedStateChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        print("✅ 全局初始化完成")
    }
    
    @objc func handlePinnedStateChange() {
        print("📢 UserDefaults changed, checking isPinnedToDesktop")
        print("   isPinnedToDesktop: \(isPinnedToDesktop)")
        
        if isPinnedToDesktop {
            print("   Showing desktop window")
            popover.performClose(nil)
            desktopWindowController?.show()
        } else {
            print("   Hiding desktop window")
            desktopWindowController?.hide()
        }
    }

    // ... (rest of the functions remain same, but I'll update togglePopover for the pinning logic later)
    
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
        
        // 如果已經釘選在桌面，點擊 Menu Bar 圖標應該視為無效或重新激活桌面視窗
        if isPinnedToDesktop {
            print("⚓ 已釘選在桌面，僅激活桌面視窗")
            desktopWindowController?.show()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
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
    
    func pinToDesktop() {
        print("📌 pinToDesktop() called")
        print("   Current isPinnedToDesktop: \(isPinnedToDesktop)")
        print("   DesktopWindowController exists: \(desktopWindowController != nil)")
        
        isPinnedToDesktop = true
        popover.performClose(nil)
        
        if let controller = desktopWindowController {
            print("   Calling desktopWindowController.show()")
            controller.show()
        } else {
            print("   ❌ DesktopWindowController is nil!")
        }
    }
    
    func unpinFromDesktop() {
        print("🔓 unpinFromDesktop() called")
        isPinnedToDesktop = false
        desktopWindowController?.hide()
    }
}
