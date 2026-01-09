import Foundation
import MapKit

/// 地圖服務類別
/// 負責地點搜尋、路線計算、地圖縮圖生成
class MapService {
    // MARK: - Singleton
    static let shared = MapService()
    
    private init() {}
    
    // MARK: - Place Search
    
    /// 搜尋地點
    /// - Parameter query: 搜尋關鍵字（地址或地點名稱）
    /// - Returns: 搜尋結果列表
    func searchPlace(query: String) async throws -> [MKMapItem] {
        guard !query.isEmpty else { return [] }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            throw MapServiceError.searchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Route Calculation
    
    /// 計算路線
    /// - Parameters:
    ///   - from: 起點座標
    ///   - to: 終點座標
    ///   - transportType: 交通方式（開車、步行、大眾運輸）
    /// - Returns: 路線資訊
    func calculateRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async throws -> MKRoute {
        let sourcePlacemark = MKPlacemark(coordinate: from)
        let destinationPlacemark = MKPlacemark(coordinate: to)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else {
                throw MapServiceError.noRouteFound
            }
            return route
        } catch {
            throw MapServiceError.routeCalculationFailed(error.localizedDescription)
        }
    }
    
    /// 計算多種交通方式的路線
    /// - Parameters:
    ///   - from: 起點座標
    ///   - to: 終點座標
    /// - Returns: 包含開車、步行、大眾運輸的路線資訊
    func calculateAllRoutes(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> (driving: MKRoute?, walking: MKRoute?, transit: MKRoute?) {
        async let drivingRoute = try? calculateRoute(from: from, to: to, transportType: .automobile)
        async let walkingRoute = try? calculateRoute(from: from, to: to, transportType: .walking)
        async let transitRoute = try? calculateRoute(from: from, to: to, transportType: .transit)
        
        return await (drivingRoute, walkingRoute, transitRoute)
    }
    
    // MARK: - Map Snapshot
    
    /// 生成地圖縮圖
    /// - Parameters:
    ///   - route: 路線資訊
    ///   - size: 圖片大小
    /// - Returns: 地圖圖片
    func generateMapSnapshot(
        route: MKRoute,
        size: CGSize
    ) async throws -> NSImage {
        let options = MKMapSnapshotter.Options()
        
        // 設定顯示區域，使用 MKCoordinateRegion 更好控制縮放係數
        let mapRect = route.polyline.boundingMapRect
        var region = MKCoordinateRegion(mapRect)
        
        // 增加 50% 的邊距（Span 乘以 1.5），確保路線不會貼邊
        region.span.latitudeDelta *= 1.5
        region.span.longitudeDelta *= 1.5
        
        // 使用 2x 尺寸進行渲染
        let renderSize = CGSize(width: size.width * 2, height: size.height * 2)
        options.region = region
        options.size = renderSize
        options.appearance = NSAppearance.currentDrawing()
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            let baseImage = snapshot.image
            
            // 轉為高品質黑白高對比度
            var renderedBaseImage: NSImage = baseImage
            if let ciImage = CIImage(data: baseImage.tiffRepresentation!) {
                let monoFilter = CIFilter(name: "CIPhotoEffectMono")
                monoFilter?.setValue(ciImage, forKey: kCIInputImageKey)
                
                let colorFilter = CIFilter(name: "CIColorControls")
                colorFilter?.setValue(monoFilter?.outputImage, forKey: kCIInputImageKey)
                colorFilter?.setValue(1.5, forKey: kCIInputContrastKey)
                colorFilter?.setValue(0.1, forKey: kCIInputBrightnessKey)
                
                let sharpenFilter = CIFilter(name: "CIUnsharpMask")
                sharpenFilter?.setValue(colorFilter?.outputImage, forKey: kCIInputImageKey)
                sharpenFilter?.setValue(2.0, forKey: kCIInputRadiusKey)
                sharpenFilter?.setValue(1.0, forKey: kCIInputIntensityKey)
                
                if let output = sharpenFilter?.outputImage {
                    let rep = NSCIImageRep(ciImage: output)
                    let monochromeImage = NSImage(size: renderSize)
                    monochromeImage.addRepresentation(rep)
                    renderedBaseImage = monochromeImage
                }
            }
            
            // 在地圖上繪製路線（使用 2x 畫布）
            let finalImage = NSImage(size: renderSize)
            finalImage.lockFocus()
            
            // 繪製基礎地圖
            renderedBaseImage.draw(at: .zero, from: NSRect(origin: .zero, size: renderSize), operation: .copy, fraction: 1.0)
            
            // 繪製路線
            let context = NSGraphicsContext.current?.cgContext
            context?.setStrokeColor(NSColor.systemBlue.cgColor)
            context?.setLineWidth(8) // 2x 畫布，線條也要加粗
            context?.setLineCap(.round)
            context?.setLineJoin(.round)
            
            let points = route.polyline.points()
            let pointCount = route.polyline.pointCount
            
            if pointCount > 0 {
                let firstPoint = snapshot.point(for: points[0].coordinate)
                context?.move(to: firstPoint)
                
                for i in 1..<pointCount {
                    let point = snapshot.point(for: points[i].coordinate)
                    context?.addLine(to: point)
                }
                context?.strokePath()
            }
            
            // 繪製起點（藍色點）
            if pointCount > 0 {
                let point = snapshot.point(for: points[0].coordinate)
                let markerRect = NSRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)
                context?.setFillColor(NSColor.systemBlue.cgColor)
                context?.fillEllipse(in: markerRect)
                context?.setStrokeColor(NSColor.white.cgColor)
                context?.setLineWidth(4)
                context?.strokeEllipse(in: markerRect)
            }
            
            // 繪製終點（紅色點）
            if pointCount > 0 {
                let point = snapshot.point(for: points[pointCount - 1].coordinate)
                let markerRect = NSRect(x: point.x - 20, y: point.y - 20, width: 40, height: 40)
                context?.setFillColor(NSColor.systemRed.cgColor)
                context?.fillEllipse(in: markerRect)
                context?.setStrokeColor(NSColor.white.cgColor)
                context?.setLineWidth(4)
                context?.strokeEllipse(in: markerRect)
            }
            
            finalImage.unlockFocus()
            return finalImage
        } catch {
            throw MapServiceError.snapshotFailed(error.localizedDescription)
        }
    }
    
    /// 生成簡單的地圖縮圖（不含路線）
    /// - Parameters:
    ///   - coordinate: 中心座標
    ///   - size: 圖片大小
    ///   - span: 地圖範圍（經緯度跨度）
    /// - Returns: 地圖圖片
    func generateSimpleSnapshot(
        coordinate: CLLocationCoordinate2D,
        size: CGSize,
        span: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ) async throws -> NSImage {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, span: span)
        options.size = CGSize(width: size.width * 2, height: size.height * 2)
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            let baseImage = snapshot.image
            
            // 轉為高品質黑白
            if let ciImage = CIImage(data: baseImage.tiffRepresentation!) {
                let monoFilter = CIFilter(name: "CIPhotoEffectMono")
                monoFilter?.setValue(ciImage, forKey: kCIInputImageKey)
                
                let colorFilter = CIFilter(name: "CIColorControls")
                colorFilter?.setValue(monoFilter?.outputImage, forKey: kCIInputImageKey)
                colorFilter?.setValue(1.5, forKey: kCIInputContrastKey)
                
                let sharpenFilter = CIFilter(name: "CIUnsharpMask")
                sharpenFilter?.setValue(colorFilter?.outputImage, forKey: kCIInputImageKey)
                sharpenFilter?.setValue(2.0, forKey: kCIInputRadiusKey)
                sharpenFilter?.setValue(1.0, forKey: kCIInputIntensityKey)
                
                if let output = sharpenFilter?.outputImage {
                    let rep = NSCIImageRep(ciImage: output)
                    let monochromeImage = NSImage(size: size)
                    monochromeImage.addRepresentation(rep)
                    return monochromeImage
                }
            }
            
            return baseImage
        } catch {
            throw MapServiceError.snapshotFailed(error.localizedDescription)
        }
    }
}

// MARK: - MapServiceError
enum MapServiceError: Error, LocalizedError {
    case emptyQuery
    case searchFailed(String)
    case noRouteFound
    case routeCalculationFailed(String)
    case snapshotFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "搜尋關鍵字不能為空"
        case .searchFailed(let message):
            return "搜尋失敗：\(message)"
        case .noRouteFound:
            return "找不到路線"
        case .routeCalculationFailed(let message):
            return "路線計算失敗：\(message)"
        case .snapshotFailed(let message):
            return "地圖生成失敗：\(message)"
        }
    }
}
