# MapKit 地點功能整合 - 詳細實作計畫

## 🎯 專案目標

為 MenuBarCalendar 添加地點功能，包括：
- 地點輸入與搜尋
- 地圖路線顯示
- 通勤時間計算
- 智能出發提醒
- 漸進式地圖展開/放大

---

## 📊 整體時程規劃

| 階段 | 功能 | 預估時間 | 風險等級 |
|------|------|---------|---------|
| Phase 0 | 準備工作 | 30 分鐘 | ⭐ 極低 |
| Phase 1 | 基礎設施 | 2 小時 | ⭐ 極低 |
| Phase 2 | 地點輸入 | 3 小時 | ⭐⭐ 低 |
| Phase 3 | 路線計算 | 3 小時 | ⭐⭐⭐ 中 |
| Phase 4 | 地圖顯示 | 4 小時 | ⭐⭐⭐⭐ 中高 |
| Phase 5 | 動畫優化 | 2 小時 | ⭐⭐ 低 |
| Phase 6 | 測試優化 | 2 小時 | ⭐⭐ 低 |
| **總計** | | **16-18 小時** | |

---

## 🛡️ Phase 0: 準備工作（30 分鐘）

### 目標
確保開發環境安全，不影響現有功能

### 任務清單

#### 1. 創建 Git 分支
```bash
cd /Users/kelvintan/Desktop/Mac\ Calendar\ Design/MenuBarCalendar
git checkout -b feature/mapkit-location
git push -u origin feature/mapkit-location
```

#### 2. 備份當前狀態
```bash
# 確認當前版本
git log --oneline -1

# 創建備份標籤
git tag -a backup-before-mapkit -m "Backup before MapKit integration"
git push origin backup-before-mapkit
```

#### 3. 驗證編譯
```bash
xcodebuild -project MenuBarCalendar.xcodeproj -scheme MenuBarCalendar clean build
```

### 驗收標準
- ✅ 新分支創建成功
- ✅ 備份標籤已推送
- ✅ 編譯成功無錯誤
- ✅ 現有功能正常運作

### 回退方案
```bash
git checkout main
git branch -D feature/mapkit-location
```

---

## 🌱 Phase 1: 基礎設施（2 小時）

### 目標
添加 MapKit 所需的權限和基礎服務類別

### 任務清單

#### 1.1 更新 Info.plist 權限（15 分鐘）

**檔案：** `MenuBarCalendar/Info.plist`

**新增內容：**
```xml
<!-- 位置權限說明 -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>用於計算到會議地點的通勤時間和顯示路線</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>用於提供基於位置的提醒功能（例如：到達時提醒）</string>
```

**驗證：**
- 運行應用
- 檢查位置權限彈窗是否正常顯示

#### 1.2 創建 LocationService（45 分鐘）

**新檔案：** `MenuBarCalendar/Services/LocationService.swift`

**功能：**
- 管理位置權限
- 取得當前位置
- 反向地理編碼（座標 → 地址）

**程式碼架構：**
```swift
import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    private let locationManager = CLLocationManager()
    
    override init() {
        // 初始化
    }
    
    func requestPermission() {
        // 請求權限
    }
    
    func getCurrentLocation() {
        // 取得位置
    }
    
    func reverseGeocode(location: CLLocation) {
        // 地址轉換
    }
}
```

**測試：**
- 創建測試視圖顯示當前位置
- 驗證權限請求流程
- 驗證地址轉換功能

#### 1.3 創建 MapService（60 分鐘）

**新檔案：** `MenuBarCalendar/Services/MapService.swift`

**功能：**
- 地點搜尋
- 路線計算
- 通勤時間預估

**程式碼架構：**
```swift
import Foundation
import MapKit

class MapService {
    func searchPlace(query: String) async throws -> [MKMapItem] {
        // 搜尋地點
    }
    
    func calculateRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) async throws -> MKRoute {
        // 計算路線
    }
    
    func generateMapSnapshot(
        route: MKRoute,
        size: CGSize
    ) async throws -> NSImage {
        // 生成地圖縮圖
    }
}
```

**測試：**
- 搜尋「台北 101」
- 計算路線
- 生成地圖圖片

### 驗收標準
- ✅ 位置權限正常請求
- ✅ 可以取得當前位置
- ✅ 地點搜尋功能正常
- ✅ 路線計算功能正常
- ✅ 現有功能不受影響

### 預估檔案
```
MenuBarCalendar/
├── Services/
│   ├── LocationService.swift (新增)
│   └── MapService.swift (新增)
└── Info.plist (修改)
```

---

## 🌿 Phase 2: 地點輸入（3 小時）

### 目標
在 AddEventView 添加地點輸入功能

### 任務清單

#### 2.1 更新 CalendarModels（30 分鐘）

**檔案：** `MenuBarCalendar/CalendarModels.swift`

**修改：**
```swift
struct CalendarEvent: Identifiable {
    // 現有屬性...
    
    // 新增地點相關屬性
    var location: String?
    var locationCoordinate: CLLocationCoordinate2D?
    var placemarkName: String?
}
```

**驗證：**
- 編譯成功
- 現有事件創建不受影響

#### 2.2 創建地點搜尋組件（90 分鐘）

**新檔案：** `MenuBarCalendar/Components/LocationSearchField.swift`

**功能：**
- 輸入地點名稱
- 自動補全建議
- 選擇地點

**UI 設計：**
```swift
struct LocationSearchField: View {
    @Binding var selectedLocation: String?
    @State private var searchText = ""
    @State private var suggestions: [MKMapItem] = []
    
    var body: some View {
        VStack {
            TextField("地點（選填）", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            if !suggestions.isEmpty {
                // 建議列表
                ScrollView {
                    ForEach(suggestions, id: \.self) { item in
                        // 建議項目
                    }
                }
            }
        }
    }
}
```

#### 2.3 整合到 AddEventView（60 分鐘）

**檔案：** `MenuBarCalendar/AddEventView.swift`

**修改位置：** 在日期時間選擇器下方添加地點欄位

**程式碼：**
```swift
// 在 Form 中添加
Section {
    LocationSearchField(selectedLocation: $event.location)
}
```

**驗證：**
- 可以搜尋地點
- 可以選擇地點
- 地點資訊正確儲存
- 不選擇地點時事件仍可創建

### 驗收標準
- ✅ 地點輸入欄位正常顯示
- ✅ 自動補全功能正常
- ✅ 地點資訊正確儲存
- ✅ 地點為可選項（不影響現有流程）
- ✅ 無地點的事件正常運作

### 預估檔案
```
MenuBarCalendar/
├── Components/
│   └── LocationSearchField.swift (新增)
├── CalendarModels.swift (修改)
└── AddEventView.swift (修改)
```

---

## 🌳 Phase 3: 路線計算（3 小時）

### 目標
計算通勤時間並顯示基本資訊

### 任務清單

#### 3.1 創建路線資料模型（30 分鐘）

**新檔案：** `MenuBarCalendar/Models/RouteInfo.swift`

**內容：**
```swift
struct RouteInfo {
    let distance: Double           // 距離（公尺）
    let expectedTravelTime: TimeInterval  // 預估時間（秒）
    let route: MKRoute
    
    var distanceText: String {
        // 格式化距離
    }
    
    var travelTimeText: String {
        // 格式化時間
    }
    
    var suggestedDepartureTime: Date {
        // 計算建議出發時間
    }
}
```

#### 3.2 創建路線計算 ViewModel（90 分鐘）

**新檔案：** `MenuBarCalendar/ViewModels/RouteViewModel.swift`

**功能：**
- 計算路線
- 快取結果
- 錯誤處理

**程式碼架構：**
```swift
@MainActor
class RouteViewModel: ObservableObject {
    @Published var routeInfo: RouteInfo?
    @Published var isCalculating = false
    @Published var error: Error?
    
    private let mapService = MapService()
    private let locationService = LocationService.shared
    
    func calculateRoute(to destination: CLLocationCoordinate2D) async {
        // 計算路線
    }
}
```

#### 3.3 在事件詳情中顯示路線資訊（60 分鐘）

**檔案：** `MenuBarCalendar/Mac Calendar Popover View.swift`

**修改：** 在事件詳情中添加路線資訊顯示

**UI 設計：**
```swift
if let location = event.location {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Image(systemName: "mappin.circle.fill")
            Text(location)
        }
        
        if let routeInfo = routeViewModel.routeInfo {
            HStack {
                Label(routeInfo.distanceText, systemImage: "ruler")
                Label(routeInfo.travelTimeText, systemImage: "car")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}
```

**驗證：**
- 有地點的事件顯示路線資訊
- 無地點的事件不顯示
- 計算失敗時顯示錯誤訊息

### 驗收標準
- ✅ 路線計算功能正常
- ✅ 距離和時間正確顯示
- ✅ 錯誤處理完善
- ✅ 無地點事件不受影響

### 預估檔案
```
MenuBarCalendar/
├── Models/
│   └── RouteInfo.swift (新增)
├── ViewModels/
│   └── RouteViewModel.swift (新增)
└── Mac Calendar Popover View.swift (修改)
```

---

## 🌲 Phase 4: 地圖顯示（4 小時）

### 目標
實作完整的地圖展開/放大功能

### 任務清單

#### 4.1 創建地圖縮圖組件（90 分鐘）

**新檔案：** `MenuBarCalendar/Components/MapSnapshotView.swift`

**功能：**
- 生成地圖縮圖
- 顯示路線
- 快取圖片

**程式碼架構：**
```swift
struct MapSnapshotView: View {
    let route: MKRoute
    let size: CGSize
    
    @State private var mapImage: NSImage?
    
    var body: some View {
        if let image = mapImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ProgressView()
                .onAppear {
                    generateSnapshot()
                }
        }
    }
    
    private func generateSnapshot() async {
        // 生成地圖縮圖
    }
}
```

#### 4.2 創建地圖詳情視圖（120 分鐘）

**新檔案：** `MenuBarCalendar/Views/EventLocationDetailView.swift`

**功能：**
- 三種狀態切換（hidden/compact/expanded）
- 動畫過渡
- 按鈕邏輯

**程式碼架構：**
```swift
struct EventLocationDetailView: View {
    let event: CalendarEvent
    @State private var mapState: MapState = .hidden
    @State private var popoverWidth: CGFloat = 350
    
    enum MapState {
        case hidden
        case compact   // 350px
        case expanded  // 500px
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with dynamic button
            header
            
            // Map section (if visible)
            if mapState != .hidden {
                mapSection
            }
        }
        .frame(width: popoverWidth)
    }
    
    @ViewBuilder
    private var header: some View {
        // 標題 + 動態按鈕
    }
    
    @ViewBuilder
    private var mapSection: some View {
        // 地圖 + 資訊卡
    }
}
```

#### 4.3 整合到現有 Popover（90 分鐘）

**檔案：** `MenuBarCalendar/Mac Calendar Popover View.swift`

**修改：**
- 替換現有事件詳情為新的 `EventLocationDetailView`
- 保持現有功能不變

**驗證：**
- 無地點事件：顯示原有介面
- 有地點事件：顯示新介面
- 動畫流暢
- 按鈕功能正確

### 驗收標準
- ✅ 地圖正確顯示
- ✅ 三種狀態切換正常
- ✅ 動畫流暢自然
- ✅ 按鈕邏輯正確
- ✅ 無地點事件不受影響

### 預估檔案
```
MenuBarCalendar/
├── Components/
│   └── MapSnapshotView.swift (新增)
├── Views/
│   └── EventLocationDetailView.swift (新增)
└── Mac Calendar Popover View.swift (修改)
```

---

## 🎨 Phase 5: 動畫優化（2 小時）

### 目標
優化動畫效果和用戶體驗

### 任務清單

#### 5.1 優化過渡動畫（60 分鐘）

**調整項目：**
- 地圖滑入動畫
- 寬度展開動畫
- 按鈕切換動畫

**程式碼優化：**
```swift
// 使用彈簧動畫
withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
    mapState = .expanded
    popoverWidth = 500
}

// 地圖滑入使用 transition
.transition(.move(edge: .bottom).combined(with: .opacity))
```

#### 5.2 添加載入狀態（30 分鐘）

**功能：**
- 地圖生成時顯示載入動畫
- 路線計算時顯示進度

**UI 設計：**
```swift
if isCalculating {
    ProgressView("計算路線中...")
        .padding()
}
```

#### 5.3 添加錯誤處理 UI（30 分鐘）

**功能：**
- 無法取得位置時的提示
- 路線計算失敗時的提示
- 重試按鈕

### 驗收標準
- ✅ 動畫流暢無卡頓
- ✅ 載入狀態清晰
- ✅ 錯誤訊息友善

---

## 🧪 Phase 6: 測試優化（2 小時）

### 目標
全面測試並修復問題

### 測試清單

#### 6.1 功能測試（60 分鐘）

**測試場景：**
- [ ] 創建無地點事件
- [ ] 創建有地點事件
- [ ] 編輯事件地點
- [ ] 刪除事件地點
- [ ] 地圖展開/收起
- [ ] 地圖放大/縮小
- [ ] 點擊打開 Apple Maps
- [ ] 點擊打開 Google Maps

#### 6.2 邊界測試（30 分鐘）

**測試場景：**
- [ ] 無網路連線
- [ ] 位置權限被拒絕
- [ ] 搜尋不到地點
- [ ] 無法計算路線
- [ ] 極遠距離（>100km）
- [ ] 極近距離（<100m）

#### 6.3 性能測試（30 分鐘）

**測試項目：**
- [ ] 地圖生成速度
- [ ] 記憶體使用
- [ ] CPU 使用
- [ ] 動畫流暢度

### 驗收標準
- ✅ 所有功能測試通過
- ✅ 邊界情況處理完善
- ✅ 性能符合預期
- ✅ 無記憶體洩漏

---

## 📦 最終交付

### 交付清單

#### 1. 程式碼
- [ ] 所有新檔案已添加
- [ ] 所有修改已完成
- [ ] 程式碼已格式化
- [ ] 註解完整

#### 2. 測試
- [ ] 所有測試通過
- [ ] 無已知 Bug
- [ ] 性能符合預期

#### 3. 文檔
- [ ] README 更新
- [ ] CHANGELOG 更新
- [ ] 使用說明完整

#### 4. Git
- [ ] 所有變更已提交
- [ ] Commit 訊息清晰
- [ ] 準備合併到 main

### 合併流程

```bash
# 1. 確認所有測試通過
xcodebuild test

# 2. 合併到 main
git checkout main
git merge feature/mapkit-location

# 3. 推送到遠端
git push origin main

# 4. 創建版本標籤
git tag -a v2.1.0 -m "Add MapKit location features"
git push origin v2.1.0
```

---

## 🎯 成功指標

### 功能完整性
- ✅ 可以輸入地點
- ✅ 可以搜尋地點
- ✅ 可以計算路線
- ✅ 可以顯示地圖
- ✅ 可以展開/放大地圖
- ✅ 可以打開外部地圖

### 用戶體驗
- ✅ 動畫流暢
- ✅ 操作直觀
- ✅ 錯誤處理完善
- ✅ 載入速度快

### 程式品質
- ✅ 程式碼整潔
- ✅ 架構清晰
- ✅ 無記憶體洩漏
- ✅ 性能良好

---

## 🚨 風險管理

### 已知風險

#### 1. 位置權限被拒絕
**影響：** 無法計算路線  
**緩解：** 提供清晰的權限說明，允許手動輸入地址

#### 2. 地圖生成緩慢
**影響：** 用戶體驗不佳  
**緩解：** 添加載入動畫，實作快取機制

#### 3. API 限制
**影響：** 功能受限  
**緩解：** MapKit 無限制，無此風險

### 回退計畫

如果遇到無法解決的問題：
```bash
# 回退到 main 分支
git checkout main

# 刪除功能分支
git branch -D feature/mapkit-location

# 恢復到備份點
git checkout backup-before-mapkit
```

---

## 📞 支援資源

### Apple 官方文檔
- [MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [Core Location Documentation](https://developer.apple.com/documentation/corelocation)

### 範例專案
- Apple Sample Code: MapKit Examples

---

**準備好開始了嗎？** 🚀

建議從 **Phase 0** 開始，逐步推進。每個 Phase 完成後都要：
1. 測試驗證
2. Git 提交
3. 確認無問題再進入下一階段

有任何問題隨時告訴我！
