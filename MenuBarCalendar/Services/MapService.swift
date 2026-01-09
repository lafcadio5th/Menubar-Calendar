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
        guard !query.isEmpty else {
            throw MapServiceError.emptyQuery
        }
        
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
        
        // 設定地圖區域（包含整條路線）
        let rect = route.polyline.boundingMapRect
        let insets = NSEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
        options.mapRect = rect
        options.size = size
        
        // 設定地圖類型
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            
            // 在地圖上繪製路線
            let image = NSImage(size: size)
            image.lockFocus()
            
            // 繪製基礎地圖
            snapshot.image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
            
            // 繪製路線
            let context = NSGraphicsContext.current?.cgContext
            context?.setStrokeColor(NSColor.systemBlue.cgColor)
            context?.setLineWidth(4)
            context?.setLineCap(.round)
            context?.setLineJoin(.round)
            
            // 轉換路線座標到圖片座標
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
            
            // 繪製起點標記（藍色圓點）
            if pointCount > 0 {
                let firstPoint = points[0]
                let point = snapshot.point(for: firstPoint.coordinate)
                let markerRect = NSRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
                
                context?.setFillColor(NSColor.systemBlue.cgColor)
                context?.fillEllipse(in: markerRect)
                
                context?.setStrokeColor(NSColor.white.cgColor)
                context?.setLineWidth(2)
                context?.strokeEllipse(in: markerRect)
            }
            
            // 繪製終點標記（紅色圖釘）
            if pointCount > 0 {
                let lastPoint = points[pointCount - 1]
                let point = snapshot.point(for: lastPoint.coordinate)
                let markerRect = NSRect(x: point.x - 12, y: point.y - 24, width: 24, height: 24)
                
                context?.setFillColor(NSColor.systemRed.cgColor)
                context?.fillEllipse(in: markerRect)
                
                context?.setStrokeColor(NSColor.white.cgColor)
                context?.setLineWidth(2)
                context?.strokeEllipse(in: markerRect)
            }
            
            image.unlockFocus()
            
            return image
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
        options.size = size
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            return snapshot.image
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
