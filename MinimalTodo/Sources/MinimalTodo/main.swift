import AppKit
import SwiftUI

// 无边框面板，允许成为 Key Window（否则输入框无法获得焦点）
final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

enum SnapCorner { case topLeft, topRight }

final class PanelController {
    static let shared = PanelController()
    weak var panel: NSPanel?

    func toggle() {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil) } else { panel.makeKeyAndOrderFront(nil) }
    }

    func hide() { panel?.orderOut(nil) }

    func snap(to corner: SnapCorner) {
        guard let panel else { return }
        guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let frame = panel.frame
        let margin: CGFloat = 12
        let x: CGFloat = corner == .topLeft
            ? visibleFrame.minX + margin
            : visibleFrame.maxX - frame.width - margin
        let y = visibleFrame.maxY - frame.height - margin
        panel.setFrame(NSRect(x: x, y: y, width: frame.width, height: frame.height),
                       display: true, animate: true)
    }

    func applyOpacity(_ value: Double) {
        panel?.alphaValue = CGFloat(value)
    }

    func applyAlwaysOnTop(_ onTop: Bool) {
        panel?.level = onTop ? .floating : .normal
    }

    func applyDock(_ visible: Bool) {
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }

    func show() {
        panel?.makeKeyAndOrderFront(nil)
    }

    /// 调整窗口大小，保持顶边位置不变（向右下扩展）
    func resize(width: CGFloat, height: CGFloat) {
        guard let panel else { return }
        var frame = panel.frame
        let deltaHeight = height - frame.height
        frame.size = NSSize(width: width, height: height)
        frame.origin.y -= deltaHeight
        panel.setFrame(frame, display: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: Panel!
    private let store = TodoStore()
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()
        setupPanel()
        PanelController.shared.applyOpacity(UserDefaults.standard.double(forKey: "mt.opacity"))
        PanelController.shared.applyAlwaysOnTop(UserDefaults.standard.bool(forKey: "mt.alwaysOnTop"))
        PanelController.shared.applyDock(UserDefaults.standard.bool(forKey: "mt.showDock"))
        store.rescheduleReminders()
        setupStatusItem()
        panel.makeKeyAndOrderFront(nil)
    }

    // 点击 Dock 图标时重新显示面板
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelController.shared.show()
        return true
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "mt.opacity": 1.0,
            "mt.fontSize": 12.0,
            "mt.alwaysOnTop": true,
            "mt.playSound": true,
            "mt.hapticFeedback": true,
            "mt.bgStyle": "system",
            "mt.showDock": true
        ])
    }

    private func setupPanel() {
        let size = NSSize(width: 320, height: 460)
        panel = Panel(contentRect: initialFrame(size: size),
                      styleMask: [.borderless, .nonactivatingPanel],
                      backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: ContentView(store: store))
        panel.setFrameAutosaveName("MinimalTodoPanel")
        PanelController.shared.panel = panel
    }

    private func initialFrame(size: NSSize) -> NSRect {
        let vf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 12
        return NSRect(x: vf.maxX - size.width - margin,
                      y: vf.maxY - size.height - margin,
                      width: size.width, height: size.height)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let button = statusItem.button
        if let symbol = NSImage(systemSymbolName: "checklist", accessibilityDescription: "晨云待办") {
            button?.image = symbol
        } else {
            button?.title = "待办" // 兜底：符号不可用时显示文字
        }
        button?.toolTip = "晨云待办：点击显示/隐藏，右键菜单"
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button?.target = self
        button?.action = #selector(statusClicked)

        statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "显示 / 隐藏", action: #selector(toggleAction), keyEquivalent: "")
        statusMenu.addItem(.separator())
        statusMenu.addItem(withTitle: "退出晨云待办", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func statusClicked() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            PanelController.shared.toggle()
        }
    }

    @objc private func toggleAction() { PanelController.shared.toggle() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
