import SwiftUI

@main
struct DoNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = TodoViewModel.shared
    }

    var body: some Scene {
        Settings { }  // 空场景，app 以 LSUIElement 运行，无可见窗口
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var pinnedWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()

        // 监听钉住状态变化，管理浮动窗口
        TodoViewModel.shared.onPinChanged = { [weak self] itemId in
            if let id = itemId {
                self?.showPinnedWindow(for: id)
            } else {
                self?.hidePinnedWindow()
            }
        }

        // 切换到其他 app 或点击桌面时收回弹窗
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        // ⌘W 快捷键关闭弹窗
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: .closePopoverShortcut,
            object: nil
        )
    }

    @objc private func closePopover() {
        guard let popover = popover, popover.isShown else { return }
        popover.performClose(nil)
    }

    // MARK: - 菜单栏

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: -1)
        self.statusItem = item

        if let button = item.button {
            let image = generateMenuBarIcon()
            image.isTemplate = true
            button.image = image
            button.image?.size = NSSize(width: 20, height: 20)
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let p = NSPopover()
        p.behavior = .transient
        p.delegate = self
        self.popover = p
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "退出 Do Now", action: #selector(quitApp), keyEquivalent: "q")
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5),
                       in: sender)
        } else {
            togglePopover()
        }
    }

    // MARK: - 菜单栏图标

    private func generateMenuBarIcon() -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: 20, height: 20)
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        bgPath.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
        bgPath.lineWidth = 1.5
        bgPath.stroke()

        let check = "✓" as NSString
        let font = NSFont.systemFont(ofSize: 16, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.controlAccentColor
        ]
        let charSize = check.size(withAttributes: attrs)
        let point = NSPoint(
            x: (size.width - charSize.width) / 2,
            y: (size.height - charSize.height) / 2 - 1
        )
        check.draw(at: point, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView()
                .environment(TodoViewModel.shared)
        )
        popover.contentSize = NSSize(width: 880, height: 680)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.makeKey()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    // MARK: - 浮动窗口（钉到屏幕）

    private func showPinnedWindow(for itemId: UUID) {
        hidePinnedWindow()
        let hosting = NSHostingController(
            rootView: PinnedItemView(itemId: itemId)
                .environment(TodoViewModel.shared)
        )
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 用 NSTextField 精确测量标题宽度，再累加控件和间距
        let title = TodoViewModel.shared.findItem(itemId)?.title ?? ""
        let textField = NSTextField(labelWithString: title)
        textField.font = .systemFont(ofSize: 13)
        let textWidth = min(max(textField.attributedStringValue.size().width, 60), 300)
        let controlsWidth: CGFloat = 16 + 8 + 16 + 8  // checkbox + spacing + pin.slash + spacing
        let hPadding: CGFloat = 12 + 12 + 4 + 4       // HStack padding + background padding
        let winWidth = min(max(textWidth + controlsWidth + hPadding, 160), 420)
        win.setContentSize(NSSize(width: winWidth, height: 56))

        // 位置：优先继承上次的位置，否则右下角
        if let saved = TodoViewModel.shared.pinnedWindowFrame {
            win.setFrame(saved, display: false)
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.maxX - win.frame.width - 12
            let y = visible.minY + 60
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // 监听窗口移动，保存位置
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pinnedWindowDidMove),
            name: NSWindow.didMoveNotification,
            object: win
        )

        win.makeKeyAndOrderFront(nil)
        pinnedWindow = win
    }

    @objc private func pinnedWindowDidMove(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        TodoViewModel.shared.pinnedWindowFrame = win.frame
    }

    private func hidePinnedWindow() {
        if let win = pinnedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: win)
        }
        pinnedWindow?.close()
        pinnedWindow = nil
    }

    // MARK: - NSPopoverDelegate

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return false
    }

    func popoverDidClose(_ notification: Notification) {
        if notification.object as? NSPopover == popover {
            popover?.contentViewController = nil
        }
    }
}
