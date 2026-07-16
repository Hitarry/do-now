import Foundation
import Observation

@Observable
final class TodoViewModel {
    var items: [TodoItem] = []
    var theme: ThemeType = .system
    var draggedItemId: UUID?
    var collapsedQuadrants: Set<Quadrant> = []
    var pinnedItemId: UUID? {
        didSet {
            if let id = pinnedItemId, findItem(id) == nil {
                pinnedItemId = nil
                onPinChanged?(nil)
            }
        }
    }

    // 撤销/重做
    private var undoStack: [[TodoItem]] = []
    private var redoStack: [[TodoItem]] = []
    private let maxUndoStack = 50
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // 上次钉住的记录（退出重启后标记用）
    var lastPinnedItemId: UUID? {
        get {
            guard let s = UserDefaults.standard.string(forKey: "lastPinnedItemId") else { return nil }
            return UUID(uuidString: s)
        }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "lastPinnedItemId") }
    }

    // 浮动窗口位置（继承用）
    var pinnedWindowFrame: NSRect? {
        get {
            let x = UserDefaults.standard.double(forKey: "pinFrameX")
            let y = UserDefaults.standard.double(forKey: "pinFrameY")
            let w = UserDefaults.standard.double(forKey: "pinFrameW")
            let h = UserDefaults.standard.double(forKey: "pinFrameH")
            guard w > 0, h > 0 else { return nil }
            return NSRect(x: x, y: y, width: w, height: h)
        }
        set {
            if let f = newValue {
                UserDefaults.standard.set(f.origin.x, forKey: "pinFrameX")
                UserDefaults.standard.set(f.origin.y, forKey: "pinFrameY")
                UserDefaults.standard.set(f.size.width, forKey: "pinFrameW")
                UserDefaults.standard.set(f.size.height, forKey: "pinFrameH")
            }
        }
    }

    static let shared = TodoViewModel()

    private let saveFile: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataDir = appSupport.appendingPathComponent("DoNow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        saveFile = dataDir.appendingPathComponent("todos.json")

        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = ThemeType(rawValue: savedTheme) {
            self.theme = theme
        }

        loadItems()
    }

    // MARK: - Item Lookup

    private func findItemIndex(_ id: UUID) -> (parentIndex: Int?, childIndex: Int?) {
        for (i, item) in items.enumerated() {
            if item.id == id { return (nil, i) }
            for (j, subtask) in item.subtasks.enumerated() {
                if subtask.id == id { return (i, j) }
            }
        }
        return (nil, nil)
    }

    func findItem(_ id: UUID) -> TodoItem? {
        for item in items {
            if item.id == id { return item }
            if let subtask = item.subtasks.first(where: { $0.id == id }) { return subtask }
        }
        return nil
    }

    // MARK: - 撤销 / 重做

    private func pushUndo() {
        undoStack.append(items)
        if undoStack.count > maxUndoStack { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(items)
        items = undoStack.removeLast()
        saveItems()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(items)
        items = redoStack.removeLast()
        saveItems()
    }

    // MARK: - CRUD

    func addItem(quadrant: Quadrant) {
        pushUndo()
        let newItem = TodoItem(title: "", isCompleted: false, quadrant: quadrant)
        var copy = items
        copy.append(newItem)
        items = copy
        saveItems()
    }

    func addSubtask(to parentId: UUID) {
        pushUndo()
        guard let idx = items.firstIndex(where: { $0.id == parentId }),
              !items[idx].isSubtask else { return }
        let subtask = TodoItem(title: "", isCompleted: false, isSubtask: true,
                               quadrant: items[idx].quadrant)
        var copy = items
        copy[idx].subtasks.append(subtask)
        items = copy
        saveItems()
    }

    func deleteItem(_ id: UUID) {
        pushUndo()
        let (parentIdx, childIdx) = findItemIndex(id)
        var copy = items
        if let pi = parentIdx, let ci = childIdx {
            copy[pi].subtasks.remove(at: ci)
        } else if let ci = childIdx {
            copy.remove(at: ci)
        }
        items = copy
        saveItems()
    }

    func setItemStyle(id: UUID, color: String?, bold: Bool, italic: Bool, fontSize: Double?) {
        pushUndo()
        let (parentIdx, childIdx) = findItemIndex(id)
        var copy = items
        if let pi = parentIdx, let ci = childIdx {
            copy[pi].subtasks[ci].textColor = color
            copy[pi].subtasks[ci].isBold = bold
            copy[pi].subtasks[ci].isItalic = italic
            copy[pi].subtasks[ci].fontSize = fontSize
        } else if let ci = childIdx {
            copy[ci].textColor = color
            copy[ci].isBold = bold
            copy[ci].isItalic = italic
            copy[ci].fontSize = fontSize
        }
        items = copy
        saveItems()
    }

    func toggleCompleted(_ id: UUID) {
        pushUndo()
        let (parentIdx, childIdx) = findItemIndex(id)
        var copy = items
        if let pi = parentIdx, let ci = childIdx {
            copy[pi].subtasks[ci].isCompleted.toggle()
        } else if let ci = childIdx {
            copy[ci].isCompleted.toggle()
        }
        items = copy
        saveItems()
    }

    func updateTitle(_ id: UUID, title: String) {
        pushUndo()
        let (parentIdx, childIdx) = findItemIndex(id)
        var copy = items
        if let pi = parentIdx, let ci = childIdx {
            copy[pi].subtasks[ci].title = title
        } else if let ci = childIdx {
            copy[ci].title = title
        }
        items = copy
        saveItems()
    }

    func appendToTitle(id: UUID, text: String) {
        pushUndo()
        var copy = items
        let (parentIdx, childIdx) = findItemIndex(id)
        if let pi = parentIdx, let ci = childIdx {
            copy[pi].subtasks[ci].title += text
        } else if let ci = childIdx {
            copy[ci].title += text
        }
        items = copy
        saveItems()
    }

    // MARK: - 拖拽移动

    func moveItem(id: UUID, to newQuadrant: Quadrant) {
        pushUndo()
        let (parentIdx, childIdx) = findItemIndex(id)
        var copy = items
        if let pi = parentIdx, let ci = childIdx {
            var item = copy[pi].subtasks[ci]
            item.quadrant = newQuadrant
            item.isSubtask = false
            copy[pi].subtasks.remove(at: ci)
            copy.append(item)
        } else if let ci = childIdx {
            copy[ci].quadrant = newQuadrant
        }
        items = copy
        saveItems()
    }

    // MARK: - 已完成折叠

    func toggleCollapse(quadrant: Quadrant) {
        if collapsedQuadrants.contains(quadrant) {
            collapsedQuadrants.remove(quadrant)
        } else {
            collapsedQuadrants.insert(quadrant)
        }
    }

    func displayItems(for quadrant: Quadrant) -> [TodoItem] {
        let all = quadrantItems(quadrant)
        if collapsedQuadrants.contains(quadrant) {
            return all.filter { !$0.isCompleted }
        }
        return all
    }

    func hasVisibleCompletedItems(in quadrant: Quadrant) -> Bool {
        quadrantItems(quadrant).contains { $0.isCompleted }
    }

    // MARK: - 归档已完成

    func clearCompleted(in quadrant: Quadrant) {
        pushUndo()
        var copy = items
        let ids = copy.filter { $0.quadrant == quadrant && $0.isCompleted && !$0.isSubtask }.map { $0.id }
        copy.removeAll { ids.contains($0.id) }
        items = copy
        saveItems()
    }

    func clearAllCompleted() {
        pushUndo()
        var copy = items
        let ids = copy.filter { $0.isCompleted && !$0.isSubtask }.map { $0.id }
        copy.removeAll { ids.contains($0.id) }
        items = copy
        saveItems()
    }

    func hasCompletedItems(in quadrant: Quadrant) -> Bool {
        items.contains { $0.quadrant == quadrant && $0.isCompleted && !$0.isSubtask }
    }

    func hasAnyCompletedItems() -> Bool {
        items.contains { $0.isCompleted && !$0.isSubtask }
    }

    func quadrantItems(_ quadrant: Quadrant) -> [TodoItem] {
        items
            .filter { $0.quadrant == quadrant && !$0.isSubtask }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Theme

    func setTheme(_ theme: ThemeType) {
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }

    // MARK: - 钉到屏幕

    var isPinnedBreathingEnabled = false {
        didSet { UserDefaults.standard.set(isPinnedBreathingEnabled, forKey: "pinnedBreathingEnabled") }
    }

    var onPinChanged: ((UUID?) -> Void)?

    func pinItem(_ id: UUID) {
        pinnedItemId = id
        lastPinnedItemId = id
        onPinChanged?(id)
    }

    func unpinItem() {
        pinnedItemId = nil
        lastPinnedItemId = nil
        onPinChanged?(nil)
    }

    // MARK: - 快捷键

    var activeQuadrant: Quadrant = .urgentImportant {
        didSet { UserDefaults.standard.set(activeQuadrant.rawValue, forKey: "activeQuadrant") }
    }

// MARK: - 开机自启

    var isLaunchAtLoginEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }

    // MARK: - 导出

    func exportJSON(to url: URL) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Export JSON error: \(error)")
        }
    }

    func exportCSV(to url: URL) {
        var csv = "id,title,isCompleted,quadrant,createdAt,parentId,textColor,isBold,isItalic,fontSize\n"
        let dateFormatter = ISO8601DateFormatter()
        for item in items {
            let parentId = item.isSubtask ? "parent" : ""
            let fs1 = item.fontSize != nil ? String(item.fontSize!) : ""
            csv += "\(item.id.uuidString),\"\(escapeCSV(item.title))\",\(item.isCompleted),\(item.quadrant.rawValue),\(dateFormatter.string(from: item.createdAt)),\(parentId),\(item.textColor ?? ""),\(item.isBold),\(item.isItalic),\(fs1)\n"
            for subtask in item.subtasks {
                let fs2 = subtask.fontSize != nil ? String(subtask.fontSize!) : ""
                csv += "\(subtask.id.uuidString),\"\(escapeCSV(subtask.title))\",\(subtask.isCompleted),\(subtask.quadrant.rawValue),\(dateFormatter.string(from: subtask.createdAt)),\(item.id.uuidString),\(subtask.textColor ?? ""),\(subtask.isBold),\(subtask.isItalic),\(fs2)\n"
            }
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func escapeCSV(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\"\"")
    }

    // MARK: - 批量操作

    var isSelectionMode = false
    var selectedIds: Set<UUID> = []

    func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) }
        else { selectedIds.insert(id) }
    }

    func selectAll(in quadrant: Quadrant) {
        for item in quadrantItems(quadrant) {
            selectedIds.insert(item.id)
            for subtask in item.subtasks {
                selectedIds.insert(subtask.id)
            }
        }
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedIds.removeAll()
    }

    func batchDelete() {
        pushUndo()
        var copy = items
        copy.removeAll { selectedIds.contains($0.id) || $0.subtasks.contains(where: { selectedIds.contains($0.id) }) }
        items = copy
        selectedIds.removeAll()
        isSelectionMode = false
        saveItems()
    }

    func batchToggleCompleted() {
        pushUndo()
        var copy = items
        for i in copy.indices {
            if selectedIds.contains(copy[i].id) {
                copy[i].isCompleted.toggle()
            }
            for j in copy[i].subtasks.indices {
                if selectedIds.contains(copy[i].subtasks[j].id) {
                    copy[i].subtasks[j].isCompleted.toggle()
                }
            }
        }
        items = copy
        selectedIds.removeAll()
        isSelectionMode = false
        saveItems()
    }

    func batchMove(to target: Quadrant) {
        pushUndo()
        var copy = items
        for i in copy.indices {
            if selectedIds.contains(copy[i].id) {
                copy[i].quadrant = target
            }
        }
        items = copy
        selectedIds.removeAll()
        isSelectionMode = false
        saveItems()
    }

    // MARK: - 自动备份

    var backupDirectory: URL? {
        get {
            if let path = UserDefaults.standard.string(forKey: "backupDirectory") {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        set { UserDefaults.standard.set(newValue?.path, forKey: "backupDirectory") }
    }

    var isAutoBackupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isAutoBackupEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "isAutoBackupEnabled") }
    }

    /// 备份间隔（分钟），默认 5
    var backupIntervalMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "backupIntervalMinutes")
            return v > 0 ? v : 5
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: "backupIntervalMinutes") }
    }

    /// 备份保留天数，默认 30
    var backupMaxAgeDays: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "backupMaxAgeDays")
            return v > 0 ? v : 30
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: "backupMaxAgeDays") }
    }

    private var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastBackupDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastBackupDate") }
    }

    func saveBackup() {
        guard isAutoBackupEnabled, let dir = backupDirectory else { return }

        // 限频检查
        if let last = lastBackupDate,
           Date().timeIntervalSince(last) < Double(backupIntervalMinutes * 60) {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "DoNow_\(formatter.string(from: Date())).json"
        let url = dir.appendingPathComponent(filename)
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
            lastBackupDate = Date()
            // 清理旧备份
            cleanOldBackups(in: dir)
        } catch {
            print("Backup error: \(error)")
        }
    }

    private func cleanOldBackups(in dir: URL) {
        let cutoff = Date().addingTimeInterval(-Double(backupMaxAgeDays * 86400))
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files where file.lastPathComponent.hasPrefix("DoNow_") && file.pathExtension == "json" {
            if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
               let created = attrs.creationDate, created < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - 备份文件列表

    func listBackupFiles() -> [(url: URL, date: Date)] {
        guard let dir = backupDirectory else { return [] }
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { return [] }
        return files
            .filter { $0.lastPathComponent.hasPrefix("DoNow_") && $0.pathExtension == "json" }
            .compactMap { url in
                guard let attrs = try? url.resourceValues(forKeys: [.creationDateKey]),
                      let date = attrs.creationDate else { return nil }
                return (url, date)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - 导入 / 恢复

    func restoreFromJSON(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return false }
        pushUndo()
        items = decoded
        saveItems()
        return true
    }

    func restoreFromCSV(url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return false }

        var imported: [TodoItem] = []
        let dateFormatter = ISO8601DateFormatter()

        for line in lines.dropFirst() {
            let cols = parseCSVLine(line)
            guard cols.count >= 6 else { continue }
            guard let uuid = UUID(uuidString: cols[0]) else { continue }
            let title = cols[1]
            let isCompleted = cols[2] == "true"
            guard let quadrant = Quadrant(rawValue: cols[3]) else { continue }
            let createdAt = dateFormatter.date(from: cols[4]) ?? Date()
            let parentId = cols[5]

            if parentId.isEmpty {
                var item = TodoItem(id: uuid, title: title, isCompleted: isCompleted, quadrant: quadrant, createdAt: createdAt)
                if cols.count > 6 {
                    item.textColor = cols[6].isEmpty ? nil : cols[6]
                    item.isBold = cols[7] == "true"
                    item.isItalic = cols[8] == "true"
                    item.fontSize = Double(cols[9])
                }
                imported.append(item)
            }
        }

        // 第二遍处理子任务
        for line in lines.dropFirst() {
            let cols = parseCSVLine(line)
            guard cols.count >= 6 else { continue }
            guard let uuid = UUID(uuidString: cols[0]) else { continue }
            let parentId = cols[5]
            guard !parentId.isEmpty, let pUuid = UUID(uuidString: parentId) else { continue }
            guard let parentIdx = imported.firstIndex(where: { $0.id == pUuid }) else { continue }
            let title = cols[1]
            let isCompleted = cols[2] == "true"
            guard let quadrant = Quadrant(rawValue: cols[3]) else { continue }
            let createdAt = dateFormatter.date(from: cols[4]) ?? Date()
            let subtask = TodoItem(id: uuid, title: title, isCompleted: isCompleted, isSubtask: true, quadrant: quadrant, createdAt: createdAt)
            if cols.count > 6 {
                var s = subtask
                s.textColor = cols[6].isEmpty ? nil : cols[6]
                s.isBold = cols[7] == "true"
                s.isItalic = cols[8] == "true"
                s.fontSize = Double(cols[9])
                imported[parentIdx].subtasks.append(s)
            } else {
                imported[parentIdx].subtasks.append(subtask)
            }
        }

        guard !imported.isEmpty else { return false }
        items = imported
        saveItems()
        return true
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle() }
            else if ch == "," && !inQuotes { result.append(current); current = "" }
            else { current.append(ch) }
        }
        result.append(current)
        return result
    }

    // MARK: - Persistence

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: saveFile, options: .atomic)
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.saveBackup()
            }
        } catch {
            print("Save error: \(error)")
        }
    }

    private func loadItems() {
        guard let data = try? Data(contentsOf: saveFile),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
