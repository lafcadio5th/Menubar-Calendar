import SwiftUI
import MapKit

/// 地圖縮圖視圖
/// 顯示路線的靜態地圖圖片
struct MapSnapshotView: View {
    let route: MKRoute
    let size: CGSize
    
    @State private var mapImage: NSImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    private let mapService = MapService.shared
    
    var body: some View {
        ZStack {
            if isLoading {
                // 載入狀態
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("生成地圖中...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else if let error = error {
                // 錯誤狀態
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("地圖載入失敗")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else if let image = mapImage {
                // 地圖圖片
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                // 預設狀態
                Color(nsColor: .controlBackgroundColor)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: size) {
            await generateSnapshot()
        }
    }
    
    private func generateSnapshot() async {
        // Only set loading if we don't present an image yet or if size changed significantly?
        // Actually, just keep it simple.
        
        // Don't modify state immediately if we are in a view update?
        // .task is safe.
        // But setting isLoading = true causes a re-render.
        if mapImage == nil {
             isLoading = true
        }
        // If we already have an image, maybe don't flicker to loading unless necessary?
        // But for resize, we probably want to show loading or keep old image stretched?
        // Keep old image until new one is ready is better UX!
        // So let's NOT set isLoading = true if we have an image, just let it update.
        // But the user might want to know it's updating.
        // Let's stick to simple logic first: 
        // 1. If mapImage is nil, isLoading = true.
        // 2. Fetch.
        // 3. Update mapImage.
        
        error = nil
        
        do {
            let image = try await mapService.generateMapSnapshot(route: route, size: size)
            self.mapImage = image
            self.isLoading = false
        } catch {
            if !Task.isCancelled {
                self.error = error
                self.isLoading = false
                print("Map snapshot error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // 預覽需要模擬路線
    MapSnapshotView(
        route: MKRoute(), // 實際使用時需要真實路線
        size: CGSize(width: 350, height: 250)
    )
    .frame(width: 350, height: 250)
}
