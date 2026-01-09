import SwiftUI
import MapKit

/// 地點搜尋輸入欄位
/// 提供地點搜尋和自動補全功能
struct LocationSearchField: View {
    @Binding var selectedLocation: String?
    @Binding var selectedCoordinate: LocationCoordinate?
    
    @State private var searchText: String = ""
    @State private var suggestions: [MKMapItem] = []
    @State private var isSearching = false
    @State private var showSuggestions = false
    
    private let mapService = MapService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 搜尋欄位
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.secondary)
                
                TextField("地點（選填）", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        // 按 Enter 時自動選擇第一個建議
                        if let firstSuggestion = suggestions.first {
                            selectPlace(firstSuggestion)
                        }
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.isEmpty {
                            suggestions = []
                            showSuggestions = false
                            selectedLocation = nil
                            selectedCoordinate = nil
                        } else if newValue != selectedLocation {
                            // 只有當輸入與已選擇的地點不同時才搜尋
                            performSearch(query: newValue)
                        }
                    }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            // 建議列表
            if showSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.indices, id: \.self) { index in
                        suggestionRow(suggestions[index])
                        
                        if index < suggestions.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .frame(maxHeight: 200)
            }
        }
    }
    
    // MARK: - Suggestion Row
    @ViewBuilder
    private func suggestionRow(_ item: MKMapItem) -> some View {
        Button(action: {
            selectPlace(item)
        }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "未知地點")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    
                    if let address = item.placemark.title {
                        Text(address)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color.blue.opacity(0.05)
                .opacity(0) // 預設透明
        )
        .onHover { hovering in
            // macOS hover 效果
        }
    }
    
    // MARK: - Actions
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            suggestions = []
            showSuggestions = false
            return
        }
        
        print("📍 LocationSearchField: Starting search for '\(query)'")
        isSearching = true
        
        Task {
            do {
                let results = try await mapService.searchPlace(query: query)
                await MainActor.run {
                    suggestions = Array(results.prefix(5)) // 最多顯示 5 個建議
                    showSuggestions = !results.isEmpty
                    isSearching = false
                    print("📍 LocationSearchField: Displaying \(suggestions.count) suggestions, showSuggestions=\(showSuggestions)")
                }
            } catch {
                await MainActor.run {
                    suggestions = []
                    showSuggestions = false
                    isSearching = false
                }
            }
        }
    }
    
    private func selectPlace(_ item: MKMapItem) {
        searchText = item.name ?? item.placemark.title ?? ""
        selectedLocation = searchText
        selectedCoordinate = LocationCoordinate(
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude
        )
        
        suggestions = []
        showSuggestions = false
    }
    
    private func clearSearch() {
        searchText = ""
        selectedLocation = nil
        selectedCoordinate = nil
        suggestions = []
        showSuggestions = false
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var location: String? = nil
    @Previewable @State var coordinate: LocationCoordinate? = nil
    
    VStack {
        LocationSearchField(
            selectedLocation: $location,
            selectedCoordinate: $coordinate
        )
        .padding()
        
        if let loc = location {
            Text("已選擇：\(loc)")
                .font(.caption)
        }
    }
    .frame(width: 400)
}
