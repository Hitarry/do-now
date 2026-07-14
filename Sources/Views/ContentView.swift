import SwiftUI

extension Notification.Name {
    static let closePopoverShortcut = Notification.Name("closePopoverShortcut")
    static let openSettingsShortcut = Notification.Name("openSettingsShortcut")
    static let showShortcutsHelp = Notification.Name("showShortcutsHelp")
}

struct PopoverContentView: View {
    @Environment(TodoViewModel.self) private var viewModel

    var body: some View {
        let theme = ThemeConfig.config(for: viewModel.theme)
        return VStack(spacing: 0) {
            TopBarView()

            GeometryReader { geo in
                let halfW = geo.size.width / 2
                let halfH = geo.size.height / 2

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        QuadrantView(quadrant: .urgentImportant)
                            .frame(width: halfW, height: halfH)
                        QuadrantView(quadrant: .notUrgentImportant)
                            .frame(width: halfW, height: halfH)
                    }
                    HStack(spacing: 0) {
                        QuadrantView(quadrant: .urgentNotImportant)
                            .frame(width: halfW, height: halfH)
                        QuadrantView(quadrant: .notUrgentNotImportant)
                            .frame(width: halfW, height: halfH)
                    }
                }
            }
        }
        .frame(width: 840, height: 620)
        .background(theme.menuBarBackground)
        // 快捷键（透明按钮，仅在键盘事件链中生效）
        .background {
            Button("") { viewModel.addItem(quadrant: viewModel.activeQuadrant) }
                .keyboardShortcut("n", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
        .background {
            Button("") { NotificationCenter.default.post(name: .closePopoverShortcut, object: nil) }
                .keyboardShortcut("w", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
        .background {
            Button("") { NotificationCenter.default.post(name: .openSettingsShortcut, object: nil) }
                .keyboardShortcut(",", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
        .background {
            Button("") { NotificationCenter.default.post(name: .showShortcutsHelp, object: nil) }
                .keyboardShortcut("/", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
        .background {
            Button("") { viewModel.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
        }
        .background {
            Button("") { viewModel.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .opacity(0).frame(width: 0, height: 0)
        }
    }
}
