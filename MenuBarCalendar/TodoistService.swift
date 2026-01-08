import Foundation
import SwiftUI

class TodoistService {
    static let shared = TodoistService()
    
    // Store token in AppStorage for easy access, but service will read it dynamically
    // Actually, reading from UserDefaults directly is fine for this singleton
    private var apiToken: String {
        UserDefaults.standard.string(forKey: "todoistApiToken") ?? ""
    }
    
    private let baseURL = "https://api.todoist.com/rest/v2/tasks"
    
    func fetchTasks(for date: Date) async throws -> [TodoistTask] {
        guard !apiToken.isEmpty else { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // Filter for tasks due on this date
        // Todoist filter query syntax: due: 2023-10-27
        // URL encoding is important
        guard let encodedFilter = "due: \(dateString)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?filter=\(encodedFilter)") else {
            throw urLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw urLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([TodoistTask].self, from: data)
    }
    
    // Helper error
    private func urLError(_ code: URLError.Code) -> URLError {
        return URLError(code)
    }
}
