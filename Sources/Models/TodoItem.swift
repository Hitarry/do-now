import Foundation

enum Quadrant: String, CaseIterable, Codable {
    case urgentImportant = "urgentImportant"
    case notUrgentImportant = "notUrgentImportant"
    case urgentNotImportant = "urgentNotImportant"
    case notUrgentNotImportant = "notUrgentNotImportant"

    var title: String {
        switch self {
        case .urgentImportant: return "重要且紧急"
        case .notUrgentImportant: return "重要不紧急"
        case .urgentNotImportant: return "不重要但紧急"
        case .notUrgentNotImportant: return "不重要不紧急"
        }
    }

    var index: Int {
        switch self {
        case .urgentImportant: return 0
        case .notUrgentImportant: return 1
        case .urgentNotImportant: return 2
        case .notUrgentNotImportant: return 3
        }
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var isSubtask: Bool = false
    var quadrant: Quadrant
    var subtasks: [TodoItem] = []
    var createdAt: Date = Date()

    // 文字样式
    var textColor: String?
    var isBold: Bool = false
    var isItalic: Bool = false
    var fontSize: Double?
}
