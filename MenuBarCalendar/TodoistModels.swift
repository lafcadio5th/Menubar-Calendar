import Foundation

struct TodoistTask: Identifiable, Decodable {
    let id: String
    let content: String
    let description: String
    let isCompleted: Bool
    let due: TodoistDue?
    let url: String
    let priority: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case description
        case isCompleted = "is_completed"
        case due
        case url
        case priority
    }
}

struct TodoistDue: Decodable {
    let date: String
    let string: String
    let lang: String
    let isRecurring: Bool
    
    enum CodingKeys: String, CodingKey {
        case date
        case string
        case lang
        case isRecurring = "is_recurring"
    }
}
