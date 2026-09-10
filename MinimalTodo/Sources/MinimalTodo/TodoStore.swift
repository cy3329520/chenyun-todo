import Foundation
import AppKit
import UserNotifications

enum TodoPriority: Int, Codable {
    case low = 0, medium = 1, high = 2

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

struct Todo: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var remindDate: Date?
    var isDone = false
    var created = Date()
    var priority: TodoPriority = .low

    enum CodingKeys: String, CodingKey {
        case id, text, remindDate, isDone, created, priority
    }

    init(id: UUID = UUID(), text: String, remindDate: Date? = nil,
         isDone: Bool = false, created: Date = Date(), priority: TodoPriority = .low) {
        self.id = id
        self.text = text
        self.remindDate = remindDate
        self.isDone = isDone
        self.created = created
        self.priority = priority
    }

    // 兼容旧数据：缺少 priority 字段时默认为低
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        remindDate = try container.decodeIfPresent(Date.self, forKey: .remindDate)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        created = try container.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        priority = try container.decodeIfPresent(TodoPriority.self, forKey: .priority) ?? .low
    }
}

final class TodoStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []
    @Published var notificationDenied = false

    private let defaults: UserDefaults
    private let storageKey = "minimaltodo.todos.v1"
    private let center = UNUserNotificationCenter.current()
    // 应用内定时器：到点触发触感震动（系统通知只负责响铃与横幅）
    private var timers: [UUID: Timer] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([Todo].self, from: data) {
            todos = list
        }
    }

    var activeTodos: [Todo] { todos.filter { !$0.isDone } }
    var completedCount: Int { todos.filter { $0.isDone }.count }
    var displayTodos: [Todo] { activeTodos + todos.filter { $0.isDone } }

    func add(text: String, remindAt: Date?, priority: TodoPriority = .low) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let todo = Todo(text: trimmed, remindDate: remindAt, priority: priority)
        todos.insert(todo, at: 0)
        persist()
        if let date = remindAt { schedule(todo, at: date) }
    }

    // 拖拽排序：在展示顺序上移动，未完成的始终排在已完成之前
    func move(fromOffsets: IndexSet, toOffset: Int) {
        var ordered = displayTodos
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        todos = ordered.filter { !$0.isDone } + ordered.filter { $0.isDone }
        persist()
    }

    func toggleDone(_ id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].isDone.toggle()
        persist()
        if todos[idx].isDone {
            cancelReminder(id)
        } else if let date = todos[idx].remindDate, date > Date() {
            schedule(todos[idx], at: date)
        }
    }

    func remove(_ id: UUID) {
        todos.removeAll { $0.id == id }
        persist()
        cancelReminder(id)
    }

    func clearCompleted() {
        let ids = todos.filter { $0.isDone }.map { $0.id }
        todos.removeAll { $0.isDone }
        persist()
        ids.forEach { cancelReminder($0) }
    }

    // 启动时重新注册未触发的提醒（跨重启可靠）
    func rescheduleReminders() {
        center.removeAllPendingNotificationRequests()
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        for todo in activeTodos {
            if let date = todo.remindDate, date > Date() {
                schedule(todo, at: date)
            }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(todos) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func schedule(_ todo: Todo, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = todo.text
        if defaults.bool(forKey: "mt.playSound") {
            content.sound = .default
        }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: todo.id.uuidString, content: content, trigger: trigger)

        requestAuthorization { granted in
            DispatchQueue.main.async { self.notificationDenied = !granted }
            if granted { self.center.add(request) }
        }
        scheduleInAppTimer(for: todo, at: date)
    }

    private func scheduleInAppTimer(for todo: Todo, at date: Date) {
        timers[todo.id]?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.fireLocalReminder(for: todo)
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[todo.id] = timer
    }

    private func fireLocalReminder(for todo: Todo) {
        timers[todo.id] = nil
        guard defaults.bool(forKey: "mt.hapticFeedback") else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        _ = todo // 触感反馈即可，无需额外 UI
    }

    private func cancelReminder(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    private func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }
}
