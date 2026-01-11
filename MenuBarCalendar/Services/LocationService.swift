import Foundation
import CoreLocation
import Combine

/// 位置服務管理類別
/// 負責管理位置權限、取得當前位置、反向地理編碼
class LocationService: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = LocationService()
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var error: LocationError?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    @available(macOS, deprecated: 26.0, message: "Consider migrating to MapKit's geocoding APIs")
    private var geocoder = CLGeocoder()
    
    // MARK: - Initialization
    private override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // 移動 100 公尺才更新
    }
    
    // MARK: - Public Methods
    
    /// 請求位置權限
    func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            error = .permissionDenied
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    /// 開始更新位置
    func startUpdatingLocation() {
        guard authorizationStatus == .authorized else {
            error = .permissionDenied
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// 請求單次位置更新
    func requestLocation() {
        guard authorizationStatus == .authorized else {
            error = .permissionDenied
            return
        }
        
        locationManager.requestLocation()
    }
    
    /// 反向地理編碼：將座標轉換為地址
    func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                self.error = .geocodingFailed(error.localizedDescription)
                return
            }
            
            guard let placemark = placemarks?.first else {
                self.error = .geocodingFailed("找不到地址")
                return
            }
            
            // 組合地址
            var addressComponents: [String] = []
            
            if let city = placemark.locality {
                addressComponents.append(city)
            }
            if let district = placemark.subLocality {
                addressComponents.append(district)
            }
            if let street = placemark.thoroughfare {
                addressComponents.append(street)
            }
            if let number = placemark.subThoroughfare {
                addressComponents.append(number)
            }
            
            self.currentAddress = addressComponents.isEmpty ? "未知地址" : addressComponents.joined(separator: ", ")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        // 權限變更後自動開始更新位置
        if authorizationStatus == .authorized {
            startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        
        // 自動進行反向地理編碼
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = .locationUpdateFailed(error.localizedDescription)
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - LocationError
enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationUpdateFailed(String)
    case geocodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置權限被拒絕，請在系統設定中允許存取位置"
        case .locationUpdateFailed(let message):
            return "無法取得位置：\(message)"
        case .geocodingFailed(let message):
            return "無法取得地址：\(message)"
        }
    }
}
