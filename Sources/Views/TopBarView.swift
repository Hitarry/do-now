import SwiftUI

struct TopBarView: View {
    @Environment(TodoViewModel.self) private var viewModel
    @State private var showSettings = false
    @State private var showMovePicker = false
    @State private var showShortcutsHelp = false

    var body: some View {
        HStack {
            Text("DO NOW")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .tracking(4)

            Spacer()

            HStack(spacing: 10) {
                if viewModel.isSelectionMode {
                    // 批量操作工具栏
                    HStack(spacing: 4) {
                        batchButton("完成", icon: "checkmark") {
                            viewModel.batchToggleCompleted()
                        }
                        batchButton("删除", icon: "trash", color: .red) {
                            viewModel.batchDelete()
                        }
                        batchButton("移动", icon: "arrow.right.square") {
                            showMovePicker = true
                        }
                        .popover(isPresented: $showMovePicker) {
                            movePickerPopover
                        }

                        Divider()
                            .frame(height: 16)

                        Button("取消") {
                            viewModel.exitSelectionMode()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(6)
                } else {
                    if viewModel.items.contains(where: { !$0.isSubtask }) {
                        Button(action: { viewModel.isSelectionMode = true }) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("选择")
                    }

                    // 帮助
                    Button(action: { showShortcutsHelp = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("帮助")
                    .popover(isPresented: $showShortcutsHelp) {
                        shortcutsHelpPopover
                    }

                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings) {
                        SettingsView()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsShortcut)) { _ in
            if showSettings { showSettings = false }  // 再次按 ⌘, 关闭
            else { showShortcutsHelp = false; showSettings = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showShortcutsHelp)) { _ in
            if showShortcutsHelp { showShortcutsHelp = false }  // 再次按 ⌘/ 关闭
            else { showSettings = false; showShortcutsHelp = true }
        }
    }

    // MARK: - 帮助

    private var shortcutsHelpPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("帮助")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.bottom, 10)

            Divider()

            // 快捷键
            Text("快捷键").font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary).padding(.top, 8).padding(.bottom, 4)
            VStack(spacing: 0) {
                shortcutRow("⌘Z", "撤销操作")
                shortcutRow("⇧⌘Z", "重做操作")
                shortcutRow("⌘N", "在活跃象限新建")
                shortcutRow("⌘W", "关闭弹窗")
                shortcutRow("⌘,", "打开设置")
                shortcutRow("⌘/", "打开帮助")
            }
            .padding(.bottom, 6)

            Divider()

            // 使用技巧
            Text("使用技巧").font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary).padding(.top, 8).padding(.bottom, 4)
            tipRow("右键点击待办记录 → 钉到屏幕")
            tipRow("右键菜单栏图标 → 退出 Do Now")
            tipRow("浮动窗口可拖拽移动位置")

            Divider().padding(.top, 8)
        }
        .padding(16)
        .frame(width: 270)
    }

    private func shortcutRow(_ keys: String, _ desc: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 52, alignment: .leading)
            Text(desc)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 批量操作按钮

    private func batchButton(_ label: String, icon: String, color: Color = .accentColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var movePickerPopover: some View {
        VStack(spacing: 4) {
            Text("移动到")
                .font(.system(size: 12, weight: .semibold))
                .padding(.bottom, 4)
            ForEach(Quadrant.allCases, id: \.self) { q in
                Button(action: {
                    viewModel.batchMove(to: q)
                    showMovePicker = false
                }) {
                    HStack {
                        Circle()
                            .fill(ThemeConfig.config(for: viewModel.theme).headerColor(for: q))
                            .frame(width: 8, height: 8)
                        Text(q.title)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 160)
    }
}
