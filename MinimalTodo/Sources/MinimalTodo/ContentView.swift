import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// 背景样式视图：自动=系统材质，其余为纯色
struct StyledBackground: View {
    let style: String

    var body: some View {
        switch style {
        case "system":
            VisualEffectBackground()
        case "parchment":
            // 羊皮纸：暖米色 + 轻微上下渐变，模拟纸质
            LinearGradient(colors: [Color(hex: 0xF6EAC8), Color(hex: 0xEEDCAE)],
                           startPoint: .top, endPoint: .bottom)
        default:
            Rectangle().fill(backgroundColor)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case "white": return Color(hex: 0xFAFAFA)
        case "yellow": return Color(hex: 0xFFF3AE)
        case "orange": return Color(hex: 0xFFE0B8)
        case "blue": return Color(hex: 0xCFE4FF)
        case "green": return Color(hex: 0xD8F2DE)
        case "pink": return Color(hex: 0xFFE0EA)
        case "purple": return Color(hex: 0xE9DFFF)
        case "dark": return Color(hex: 0x26262A)
        default: return Color(hex: 0xFAFAFA)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum PanelMode { case list, reminder, settings }

struct ContentView: View {
    @ObservedObject var store: TodoStore

    // 设置项（UserDefaults 持久化）
    @AppStorage("mt.opacity") private var opacity = 1.0
    @AppStorage("mt.fontSize") private var fontSize = 12.0
    @AppStorage("mt.alwaysOnTop") private var alwaysOnTop = true
    @AppStorage("mt.playSound") private var playSound = true
    @AppStorage("mt.hapticFeedback") private var hapticFeedback = true
    @AppStorage("mt.bgStyle") private var bgStyle = "system"
    @AppStorage("mt.showDock") private var showDock = true
    @Environment(\.colorScheme) private var systemScheme

    @State private var mode: PanelMode = .list
    @State private var newText = ""
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var timeText = ""
    @State private var dateText = ""
    @State private var timeInvalid = false
    @State private var dateInvalid = false
    @State private var selectedPriority: TodoPriority = .low
    @FocusState private var timeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            content
            clearBar
            Divider().opacity(0.4)
            addBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StyledBackground(style: bgStyle))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .overlay(alignment: .bottomTrailing) {
            ResizeGrip()
                .frame(width: 18, height: 18)
                .padding(1)
        }
        .environment(\.colorScheme, effectiveScheme)
        .onChange(of: opacity) { PanelController.shared.applyOpacity($0) }
        .onChange(of: alwaysOnTop) { PanelController.shared.applyAlwaysOnTop($0) }
        .onChange(of: showDock) { PanelController.shared.applyDock($0) }
    }

    private var effectiveScheme: ColorScheme {
        switch bgStyle {
        case "dark": return .dark
        case "system": return systemScheme
        default: return .light
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("待办").font(.system(size: 13, weight: .semibold))
            Text("\(store.activeTodos.count) 项")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            headerButton("arrow.up.left", "吸附到屏幕左上角") { PanelController.shared.snap(to: .topLeft) }
            headerButton("arrow.up.right", "吸附到屏幕右上角") { PanelController.shared.snap(to: .topRight) }
            headerButton("gearshape", "设置（透明度、字体、背景、提醒方式）") {
                mode = mode == .settings ? .list : .settings
            }
            headerButton("xmark", "关闭面板（点菜单栏图标可重新打开）") { PanelController.shared.hide() }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func headerButton(_ symbol: String, _ tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    // MARK: - 主内容区（列表 / 时间选择 / 设置 三视图切换）

    @ViewBuilder private var content: some View {
        switch mode {
        case .list: listContent
        case .reminder: reminderView
        case .settings: ScrollView(showsIndicators: false) { settingsView }
        }
    }

    @ViewBuilder private var listContent: some View {
        if store.todos.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 30))
                    .foregroundStyle(.quaternary)
                Text("暂无待办").font(.system(size: 12)).foregroundStyle(.secondary)
                Text("在下方输入内容，回车即可添加").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.displayTodos) { todo in
                    TodoRow(todo: todo, store: store, fontSize: CGFloat(fontSize))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                }
                .onMove { offsets, target in
                    store.move(fromOffsets: offsets, toOffset: target)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - 提醒时间设置（日期快捷切换 + 时间直接输入）

    private var reminderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("设置提醒时间")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    mode = .list
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("保存并返回列表")
            }

            HStack(spacing: 8) {
                Text("快捷").font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                quickDayChip("今天", offset: 0)
                quickDayChip("明天", offset: 1)
                quickDayChip("后天", offset: 2)
                Spacer()
            }

            HStack(spacing: 8) {
                Text("日期").font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                TextField("9/12", text: $dateText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13).monospacedDigit())
                    .frame(width: 100)
                    .onSubmit { applyDateInput(showError: true) }
                Text("如 9/12 或 2026/9/12")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                Text("时间").font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                TextField("15:30", text: $timeText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
                    .focused($timeFieldFocused)
                    .onSubmit { applyTimeInput(showError: true) }
                    .onChange(of: timeText) { newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if (4...6).contains(digits.count) {
                            applyTimeInput(showError: false) // 输够位数即时生效
                        } else if newValue.isEmpty {
                            timeInvalid = false
                        }
                    }
                Text("如 15:30 或 15:30:25")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if dateInvalid {
                Text("日期格式不对，示例：9/12、2026/9/12")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            if timeInvalid {
                Text("时间格式不对，示例：15:30、09:05:30")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 4) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.orange)
                Text("提醒时间：\(reminderDate.formatted(.dateTime.year().month().day().hour().minute().second()))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if store.notificationDenied {
                Label("通知权限被拒绝，提醒不会弹出（请在系统设置中开启）", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            Text("到点后弹出系统通知\(playSound ? "并响铃" : "")\(hapticFeedback ? "、触感震动" : "")")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .onAppear {
            timeFieldFocused = true
        }
    }

    // 进入时间视图：初始化输入框
    private func openReminder() {
        if reminderDate < Date() {
            reminderDate = Date().addingTimeInterval(3600)
        }
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute, .second], from: reminderDate)
        timeText = String(format: "%02d:%02d:%02d",
                          time.hour ?? 0, time.minute ?? 0, time.second ?? 0)
        let day = cal.dateComponents([.year, .month, .day], from: reminderDate)
        dateText = String(format: "%d/%d/%d",
                          day.year ?? 2026, day.month ?? 1, day.day ?? 1)
        timeInvalid = false
        dateInvalid = false
        mode = .reminder
    }

    // 快捷日期胶囊（今天/明天/后天）
    private func quickDayChip(_ title: String, offset: Int) -> some View {
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date())) ?? Date()
        let selected = cal.isDate(reminderDate, inSameDayAs: target)
        return Button {
            setDay(offset: offset)
        } label: {
            Text(title)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(selected
                                           ? AnyShapeStyle(Color.accentColor.opacity(0.2))
                                           : AnyShapeStyle(Color.primary.opacity(0.05))))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // 设置日期（保持时间部分不变）
    private func setDay(offset: Int) {
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute, .second], from: reminderDate)
        var comps = cal.dateComponents([.year, .month, .day],
                                       from: cal.date(byAdding: .day, value: offset,
                                                      to: cal.startOfDay(for: Date())) ?? Date())
        comps.hour = time.hour
        comps.minute = time.minute
        comps.second = time.second
        if let date = cal.date(from: comps), let year = comps.year, let month = comps.month, let day = comps.day {
            reminderDate = date
            dateText = String(format: "%d/%d/%d", year, month, day)
            dateInvalid = false
        }
    }

    // 解析日期输入：9/12、2026/9/12、2026-9-12、2026年9月12日
    private func applyDateInput(showError: Bool) {
        func fail() {
            if showError { dateInvalid = true }
        }
        let parts = dateText.split { "/-.年月日 ".contains($0) }.map(String.init)
        let cal = Calendar.current
        var comps: DateComponents
        switch parts.count {
        case 2:
            guard let month = Int(parts[0]), let day = Int(parts[1]) else { fail(); return }
            comps = cal.dateComponents([.hour, .minute, .second], from: reminderDate)
            comps.year = cal.component(.year, from: Date())
            comps.month = month
            comps.day = day
        case 3:
            guard var year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { fail(); return }
            if year < 100 { year += 2000 }
            comps = cal.dateComponents([.hour, .minute, .second], from: reminderDate)
            comps.year = year
            comps.month = month
            comps.day = day
        default:
            fail()
            return
        }
        // 严格校验：像 2/30 这类日期会被 Calendar 顺延到 3 月，需 roundtrip 检查
        guard let date = cal.date(from: comps),
              cal.component(.day, from: date) == comps.day,
              cal.component(.month, from: date) == comps.month else {
            fail()
            return
        }
        dateInvalid = false
        reminderDate = date
        dateText = String(format: "%d/%d/%d", comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1)
    }

    // 解析时间输入：支持 930 / 1530 / 153025 / 15:30 / 15:30:25
    private func applyTimeInput(showError: Bool) {
        let digits = timeText.filter { $0.isNumber }
        var hour = 0, minute = 0, second = 0
        switch digits.count {
        case 3:
            hour = Int(digits.prefix(1)) ?? 0
            minute = Int(digits.suffix(2)) ?? 0
        case 4:
            hour = Int(digits.prefix(2)) ?? 0
            minute = Int(digits.suffix(2)) ?? 0
        case 6:
            hour = Int(digits.prefix(2)) ?? 0
            minute = Int(digits.dropFirst(2).prefix(2)) ?? 0
            second = Int(digits.suffix(2)) ?? 0
        default:
            if showError { timeInvalid = true }
            return
        }
        guard (0..<24).contains(hour), (0..<60).contains(minute), (0..<60).contains(second) else {
            if showError { timeInvalid = true }
            return
        }
        timeInvalid = false
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: reminderDate)
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        if let date = cal.date(from: comps) {
            reminderDate = date
        }
    }

    // MARK: - 设置页

    private let bgOptions: [(key: String, name: String, color: Color?)] = [
        ("system", "自动", nil),
        ("white", "白", Color(hex: 0xFAFAFA)),
        ("parchment", "羊皮纸", Color(hex: 0xF3E5C0)),
        ("yellow", "黄", Color(hex: 0xFFF3AE)),
        ("orange", "橙", Color(hex: 0xFFE0B8)),
        ("blue", "蓝", Color(hex: 0xCFE4FF)),
        ("green", "绿", Color(hex: 0xD8F2DE)),
        ("pink", "粉", Color(hex: 0xFFE0EA)),
        ("purple", "紫", Color(hex: 0xE9DFFF)),
        ("dark", "深色", Color(hex: 0x26262A))
    ]

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("设置").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    mode = .list
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("返回列表")
            }

            Group {
                Toggle("始终置顶（在所有应用最上层）", isOn: $alwaysOnTop)
                    .help("关闭后窗口不再悬浮于其他应用之上")
                Toggle("显示 Dock 图标（点击可重新打开面板）", isOn: $showDock)
                    .help("关闭后仅保留菜单栏小图标")
                HStack(spacing: 8) {
                    Text("透明度").font(.system(size: 12)).frame(width: 52, alignment: .leading)
                    Slider(value: $opacity, in: 0.3...1.0)
                    Text("\(Int(opacity * 100))%")
                        .font(.system(size: 11)).monospacedDigit()
                        .foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                }
                HStack(spacing: 8) {
                    Text("字体大小").font(.system(size: 12)).frame(width: 52, alignment: .leading)
                    Slider(value: $fontSize, in: 11...18, step: 1)
                    Text("\(Int(fontSize))pt")
                        .font(.system(size: 11)).monospacedDigit()
                        .foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                }
            }

            Divider().opacity(0.4)
            Text("背景样式").font(.system(size: 11)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(bgOptions, id: \.key) { option in
                    Button {
                        bgStyle = option.key
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(option.color ?? Color.clear)
                                    .frame(width: 20, height: 20)
                                if option.color == nil {
                                    Circle()
                                        .fill(LinearGradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0x333333)],
                                                             startPoint: .top, endPoint: .bottom))
                                        .frame(width: 20, height: 20)
                                }
                                Circle()
                                    .strokeBorder(bgStyle == option.key ? Color.accentColor : Color.primary.opacity(0.15),
                                                  lineWidth: bgStyle == option.key ? 1.5 : 0.5)
                                    .frame(width: 24, height: 24)
                            }
                            .frame(height: 26)
                            Text(option.name)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("背景：\(option.name)")
                }
            }

            Divider().opacity(0.4)
            Text("提醒方式").font(.system(size: 11)).foregroundStyle(.secondary)
            Group {
                Toggle("响铃（系统通知声音）", isOn: $playSound)
                Toggle("震动（触感反馈，需应用运行中）", isOn: $hapticFeedback)
            }

            Divider().opacity(0.4)
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出晨云待办", systemImage: "power")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .toggleStyle(.checkbox)
        .padding(12)
    }

    // MARK: - 清除已完成（仅列表视图显示）

    @ViewBuilder private var clearBar: some View {
        if mode == .list, store.completedCount > 0 {
            HStack {
                Spacer()
                Button {
                    withAnimation { store.clearCompleted() }
                } label: {
                    Text("清除已完成（\(store.completedCount)）")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除所有已完成的待办")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }

    // MARK: - 底部添加栏

    private var addBar: some View {
        HStack(spacing: 6) {
            clockButton
            TextField("添加待办，回车确认", text: $newText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit(add)
            priorityPicker
            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(newText.trimmed.isEmpty
                                     ? AnyShapeStyle(Color.secondary.opacity(0.4))
                                     : AnyShapeStyle(Color.accentColor))
            }
            .buttonStyle(.plain)
            .disabled(newText.trimmed.isEmpty)
        }
        .padding(.leading, 12)
        .padding(.trailing, 20) // 右侧留出缩放手柄位置
        .padding(.vertical, 9)
    }

    // 优先级选择（低/中/高，默认低）
    private var priorityPicker: some View {
        HStack(spacing: 3) {
            ForEach([TodoPriority.low, .medium, .high], id: \.self) { p in
                let selected = selectedPriority == p
                Button {
                    selectedPriority = p
                } label: {
                    Text(p.title)
                        .font(.system(size: 10, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(selected
                                                   ? AnyShapeStyle(priorityColor(p).opacity(0.2))
                                                   : AnyShapeStyle(Color.primary.opacity(0.05))))
                        .foregroundStyle(selected
                                         ? AnyShapeStyle(priorityColor(p))
                                         : AnyShapeStyle(Color.secondary))
                }
                .buttonStyle(.plain)
                .help("优先级：\(p.title)")
            }
        }
    }

    private func priorityColor(_ p: TodoPriority) -> Color {
        switch p {
        case .low: return .secondary
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var clockButton: some View {
        Button {
            if mode == .reminder {
                mode = .list
            } else {
                openReminder()
            }
        } label: {
            Image(systemName: mode == .reminder ? "clock.fill" : "clock")
                .font(.system(size: 13))
                .foregroundStyle(mode == .reminder
                                 ? AnyShapeStyle(Color.orange)
                                 : AnyShapeStyle(Color.secondary))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("设置提醒时间（可选）")
    }

    private func add() {
        store.add(text: newText, remindAt: mode == .reminder ? reminderDate : nil, priority: selectedPriority)
        newText = ""
        selectedPriority = .low
        mode = .list
    }
}

// MARK: - 右下角缩放手柄（原生 NSView，禁用窗口拖动劫持，只改宽高）

final class ResizeHandleView: NSView {
    var onResize: ((CGFloat, CGFloat) -> Void)?
    private var startFrame: NSRect?
    private var startPoint: NSPoint?

    // 关键：该区域不作为窗口拖动热区
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        startFrame = window.frame
        startPoint = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startFrame = startFrame, let startPoint = startPoint else { return }
        let current = NSEvent.mouseLocation
        let width = min(640, max(300, startFrame.width + (current.x - startPoint.x)))
        let height = min(1100, max(340, startFrame.height + (startPoint.y - current.y)))
        onResize?(width, height)
    }

    override func mouseUp(with event: NSEvent) {
        startFrame = nil
        startPoint = nil
    }
}

struct ResizeGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "arrow.down.right", accessibilityDescription: "拖动调整大小")
        icon.contentTintColor = .tertiaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        // 手柄置于最上层接收事件，避免事件落到底层视图导致窗口移动
        let handle = ResizeHandleView()
        handle.onResize = { width, height in
            PanelController.shared.resize(width: width, height: height)
        }
        handle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(handle)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 10),
            icon.heightAnchor.constraint(equalToConstant: 10),
            handle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            handle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            handle.topAnchor.constraint(equalTo: container.topAnchor),
            handle.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - 单行待办

struct TodoRow: View {
    let todo: Todo
    @ObservedObject var store: TodoStore
    let fontSize: CGFloat
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if hovering && !todo.isDone {
                    Button {
                        withAnimation { store.remove(todo.id) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                } else {
                    priorityFlag(todo.priority)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.text)
                    .font(.system(size: fontSize,
                                  weight: todo.priority == .high ? .semibold : .regular))
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? Color.secondary : Color.primary)
                    .lineLimit(2)
                if let date = todo.remindDate {
                    // 提醒时间：独立一行的彩色标签
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.system(size: 8))
                        Text(format(date))
                    }
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(todo.isDone
                                     ? AnyShapeStyle(Color.secondary.opacity(0.6))
                                     : AnyShapeStyle(Color.orange))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.orange.opacity(todo.isDone ? 0.08 : 0.15)))
                }
            }

            Spacer(minLength: 4)

            Button {
                withAnimation { store.toggleDone(todo.id) }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(todo.isDone ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(todo.isDone ? "标记为未完成" : "完成")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0))
        )
        .onHover { hovering = $0 }
    }

    // 优先级旗帜：低=灰色轮廓 中=橙色 高=红色
    private func priorityFlag(_ p: TodoPriority) -> some View {
        Group {
            switch p {
            case .high:
                Image(systemName: "flag.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.red)
            case .medium:
                Image(systemName: "flag.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.orange)
            case .low:
                Image(systemName: "flag")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .help("优先级：\(p.title)")
    }

    private func format(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }
}
