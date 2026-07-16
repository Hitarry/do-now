import SwiftUI
import UniformTypeIdentifiers

struct TodoRowView: View {
    @Environment(TodoViewModel.self) private var viewModel
    let itemId: UUID
    let isSubtask: Bool
    @State private var isEditing = false
    @State private var editingText = ""
    @State private var showDeleteAlert = false
    @State private var showStylePicker = false
    @State private var showSubtaskAlert = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let _ = viewModel.items.count  // 强制依赖追踪
        let theme = ThemeConfig.config(for: viewModel.theme)
        let item = viewModel.findItem(itemId)
        let isSelected = viewModel.selectedIds.contains(itemId)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                // 折叠/展开按钮（仅父级待办有子任务时）
                if !viewModel.isSelectionMode, let item = item, !item.subtasks.isEmpty {
                    Button(action: { viewModel.toggleCollapseParent(itemId) }) {
                        Image(systemName: viewModel.collapsedParentIds.contains(itemId)
                              ? "chevron.right"
                              : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.collapsedParentIds.contains(itemId) ? "展开子任务" : "收起子任务")
                }

                if viewModel.isSelectionMode {
                    // 选择模式 → 无左侧按钮，选中圆移到右侧 Spacer 区域
                } else {
                    // 正常模式 → 完成勾选框
                    Button(action: {
                        if let it = item, !it.subtasks.isEmpty, !it.subtasks.allSatisfy(\.isCompleted), !it.isCompleted {
                            showSubtaskAlert = true
                        } else {
                            viewModel.toggleCompleted(itemId)
                        }
                    }) {
                        Image(systemName: item?.isCompleted == true
                              ? "checkmark.square.fill"
                              : "square")
                            .font(.system(size: 14))
                            .foregroundColor(item?.isCompleted == true ? .green : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }

                // Title
                if isEditing && !viewModel.isSelectionMode {
                    TextField("输入待办事项...", text: $editingText)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit { commitEdit() }
                        .onChange(of: isFocused) { _, newValue in
                            // 仅当确实在编辑中且失去焦点时才提交，防止 popover 打开时误触发
                            if !newValue && isEditing && !editingText.isEmpty {
                                commitEdit()
                            } else if !newValue {
                                isEditing = false
                            }
                        }
                        .font(displayFont(item: item))
                        .foregroundColor(item?.textColor != nil ? colorFromHex(item!.textColor!) : theme.primaryText)
                        .onAppear { isFocused = true }
                } else {
                    HStack(spacing: 4) {
                        // 上次退出时钉过的标记
                        if viewModel.lastPinnedItemId == itemId && viewModel.pinnedItemId != itemId {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                                .help("上次退出时此记录被钉在屏幕上")
                        }
                        Text(item?.title.isEmpty == false ? item!.title : "点击添加待办")
                            .font(displayFont(item: item))
                            .strikethrough(item?.isCompleted ?? false)
                            .foregroundColor(item?.isCompleted == true
                                ? theme.secondaryText
                                : (item?.textColor != nil ? colorFromHex(item!.textColor!) : theme.primaryText))
                            .opacity(item?.isCompleted == true ? 0.6 : 1.0)
                            .lineLimit(2)
                    }
                    .onTapGesture {
                        guard !viewModel.isSelectionMode else {
                            viewModel.toggleSelection(itemId)
                            return
                        }
                        editingText = item?.title ?? ""
                        isEditing = true
                    }
                }

                Spacer()

                if viewModel.isSelectionMode {
                    // 选择模式 → 选中圆（移到右侧，避免与左侧完成按钮混淆）
                    Button(action: { viewModel.toggleSelection(itemId) }) {
                        Image(systemName: isSelected
                              ? "circle.circle.fill"
                              : "circle")
                            .font(.system(size: 17))
                            .foregroundColor(isSelected ? .accentColor : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                } else {
                    // 样式
                    Button(action: {
                        if isEditing { commitEdit() }
                        showStylePicker = true
                    }) {
                        Image(systemName: "textformat")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("文字样式")
                    .popover(isPresented: $showStylePicker) {
                        StylePickerView(itemId: itemId, viewModel: TodoViewModel.shared)
                            .frame(width: 255, height: 420)
                    }

                    // Add subtask (only for top-level)
                    if !isSubtask {
                        Button(action: { viewModel.addSubtask(to: itemId) }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("添加子任务")
                    }

                    // Delete
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                            .opacity(0.6)
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                    .confirmationDialog("确认删除", isPresented: $showDeleteAlert) {
                        Button("删除", role: .destructive) { viewModel.deleteItem(itemId) }
                        Button("取消", role: .cancel) { }
                    } message: {
                        Text("删除后不可恢复")
                    }
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .background(isSelected ? Color.accentColor.opacity(0.08) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            .cornerRadius(4)
            .onHover { hovering in isHovered = hovering }
            .onDrag {
                viewModel.draggedItemId = itemId
                return NSItemProvider(object: itemId.uuidString as NSString)
            }
            .contextMenu {
                if viewModel.pinnedItemId == itemId {
                    Button(action: { viewModel.unpinItem() }) {
                        Label("取消钉到屏幕", systemImage: "pin.slash")
                    }
                } else {
                    Button(action: {
                        viewModel.pinItem(itemId)
                        // 钉住后关闭主界面，释放焦点
                        NotificationCenter.default.post(name: .closePopoverShortcut, object: nil)
                    }) {
                        Label("钉到屏幕", systemImage: "pin")
                    }
                }
            }

            // Subtasks (collapsedParentIds 中则不显示)
            if let item = item, !item.subtasks.isEmpty, !viewModel.collapsedParentIds.contains(itemId) {
                ForEach(item.subtasks) { subtask in
                    TodoRowView(itemId: subtask.id, isSubtask: true)
                        .padding(.leading, 24)
                }
            }
        }
        .id(itemId)
        .onDisappear {
            if isEditing {
                viewModel.updateTitle(itemId, title: editingText)
                isEditing = false
            }
        }
        .alert("有未完成的子任务", isPresented: $showSubtaskAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("请先完成所有子任务，再标记此任务为已完成。")
        }
    }

    private func displayFont(item: TodoItem?) -> Font {
        let size = item?.fontSize ?? 14
        var font = Font.system(size: size)
        if item?.isBold == true { font = font.bold() }
        if item?.isItalic == true { font = font.italic() }
        return font
    }

    private func commitEdit() {
        guard !editingText.isEmpty else { isEditing = false; return }
        viewModel.updateTitle(itemId, title: editingText)
        isEditing = false
    }
}
