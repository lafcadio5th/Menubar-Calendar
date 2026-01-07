# Mac Menu Bar 行事曆

一個簡潔優雅的 macOS 選單列行事曆應用程式，使用 Swift 和 SwiftUI 開發。

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 功能特色

### 核心功能
- 🗓️ **選單列常駐** - 隨時快速存取行事曆
- 📅 **月曆視圖** - 清晰的月份日曆顯示
- ➕ **事件管理** - 新增、編輯、刪除事件
- 🔔 **提醒通知** - 事件開始前自動提醒
- 🎨 **顏色標記** - 為事件設定不同顏色
- 🌙 **深色模式** - 完美支援 macOS 深色模式

### 進階功能
- 📱 **系統行事曆整合** - 與 macOS 內建行事曆同步
- ⌨️ **鍵盤快捷鍵** - 方向鍵快速導航
- 🚀 **開機自動啟動** - 可選擇登入時自動啟動
- 🌏 **多語言支援** - 支援繁體中文介面

## 📁 專案結構

```
MacMenuBarCalendar/
├── MacMenuBarCalendarApp.swift    # 主程式進入點
├── Info.plist                      # 應用程式設定
├── Views/
│   ├── CalendarPopoverView.swift   # 行事曆彈出視窗
│   ├── AddEventView.swift          # 新增事件視圖
│   └── SettingsView.swift          # 設定視圖
├── ViewModels/
│   └── CalendarViewModel.swift     # 行事曆邏輯
├── Models/
│   └── CalendarModels.swift        # 資料模型
└── Services/
    ├── EventKitService.swift       # EventKit 整合
    └── NotificationService.swift   # 通知服務
```

## 🛠️ 開發環境需求

- **macOS** 13.0 (Ventura) 或更新版本
- **Xcode** 15.0 或更新版本
- **Swift** 5.9 或更新版本

## 🚀 快速開始

### 1. 建立專案

在 Xcode 中建立新專案：
1. 開啟 Xcode → File → New → Project
2. 選擇 **macOS** → **App**
3. 填入以下設定：
   - Product Name: `MacMenuBarCalendar`
   - Team: 你的開發者帳號
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**

### 2. 複製檔案

將本專案中的 Swift 檔案複製到對應位置。

### 3. 設定 Info.plist

確保以下設定正確：

```xml
<!-- 作為選單列應用程式 (無 Dock 圖標) -->
<key>LSUIElement</key>
<true/>

<!-- 行事曆存取權限 -->
<key>NSCalendarsUsageDescription</key>
<string>此應用程式需要存取您的行事曆來顯示和管理事件。</string>
```

### 4. 新增功能 (Capabilities)

在 Xcode 專案設定中啟用：
- ✅ App Sandbox
- ✅ Calendars (Read/Write)
- ✅ User Notifications

### 5. 編譯與執行

按下 `⌘ + R` 編譯並執行應用程式。

## ⌨️ 鍵盤快捷鍵

| 快捷鍵 | 功能 |
|--------|------|
| `←` `→` | 選擇前/後一天 |
| `↑` `↓` | 選擇前/後一週 |
| `⌘ + N` | 新增事件 |
| `⌘ + T` | 跳至今天 |
| `⌘ + ,` | 開啟設定 |

## 🎨 自訂主題

您可以在 `CalendarPopoverView.swift` 中自訂顏色主題：

```swift
// 修改強調色
.accentColor(.blue)

// 修改背景材質
VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
```

## 📝 待辦事項

- [ ] iCloud 同步支援
- [ ] 重複事件功能
- [ ] 農曆顯示
- [ ] 小工具 (Widget) 支援
- [ ] 多國語言在地化
- [ ] 匯入/匯出 .ics 檔案

## 🤝 貢獻

歡迎提交 Pull Request 或開啟 Issue！

## 📄 授權條款

本專案採用 MIT 授權條款 - 詳見 [LICENSE](LICENSE) 檔案。

## 🙏 致謝

- Apple 的 [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- SwiftUI 社群的各種範例與教學
