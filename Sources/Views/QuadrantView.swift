import SwiftUI
import UniformTypeIdentifiers

struct QuadrantView: View {
    @Environment(TodoViewModel.self) private var viewModel
    let quadrant: Quadrant
    @State private var isDropTargeted = false
    @State private var showMovePicker = false
    @State private var showClearConfirm = false

    private var isCollapsed: Bool {
        viewModel.collapsedQuadrants.contains(quadrant)
    }

    private var displayItems: [TodoItem] {
        viewModel.displayItems(for: quadrant)
    }

    var body: some View {
        let theme = ThemeConfig.config(for: viewModel.theme)
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.headerColor(for: quadrant))
                    .frame(width: 10, height: 10)

                Text(quadrant.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.headerColor(for: quadrant))

                Spacer()

                if !viewModel.isSelectionMode {
                    // 折叠
                    if viewModel.hasVisibleCompletedItems(in: quadrant) {
                        Button(action: { viewModel.toggleCollapse(quadrant: quadrant) }) {
                            Image(systemName: isCollapsed ? "eye" : "eye.slash")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .help(isCollapsed ? "显示已完成" : "隐藏已完成")
                    }
                    // 清除已完成
                    if viewModel.hasCompletedItems(in: quadrant) {
                        Button(action: { showClearConfirm = true }) {
                            Image(systemName: "checkmark.circle.badge.xmark")
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .help("清除已完成")
                        .confirmationDialog("确认清除", isPresented: $showClearConfirm) {
                            Button("清除", role: .destructive) { viewModel.clearCompleted(in: quadrant) }
                            Button("取消", role: .cancel) { }
                        } message: {
                            Text("将删除此象限中所有已完成的事项，此操作不可撤销。")
                        }
                    }
                    Button(action: { viewModel.addItem(quadrant: quadrant) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.headerColor(for: quadrant))
                    }
                    .buttonStyle(.plain)
                    .help("添加待办事项")
                } else {
                    // 全选
                    Button(action: { viewModel.selectAll(in: quadrant) }) {
                        Text("全选")
                            .font(.system(size: 11))
                            .foregroundColor(theme.headerColor(for: quadrant))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(viewModel.isSelectionMode
                        ? theme.headerColor(for: quadrant).opacity(0.25)
                        : theme.headerBackground(for: quadrant))

            theme.dividerColor
                .frame(height: 0.5)

            // Items list
            if displayItems.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(theme.secondaryText.opacity(0.4))
                    Text(isCollapsed ? "已完成已隐藏" : "暂无待办")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText.opacity(0.5))
                    if !isCollapsed && !viewModel.isSelectionMode {
                        Text("可从其他象限拖入")
                            .font(.system(size: 10))
                            .foregroundColor(theme.secondaryText.opacity(0.3))
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(displayItems) { item in
                            TodoRowView(itemId: item.id, isSubtask: false)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(
            Group {
                if viewModel.isSelectionMode {
                    theme.headerColor(for: quadrant).opacity(0.04)
                } else if viewModel.theme == .system {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                } else {
                    theme.quadrantBackground
                }
            }
        )
        .overlay(
            Group {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.headerColor(for: quadrant), lineWidth: 2)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(3)
        .onDrop(of: [UTType.text.identifier], isTargeted: $isDropTargeted) { providers in
            guard let id = viewModel.draggedItemId else { return false }
            viewModel.moveItem(id: id, to: quadrant)
            viewModel.draggedItemId = nil
            return true
        }
        .onTapGesture(count: 1) {
            guard !viewModel.isSelectionMode else { return }
            viewModel.activeQuadrant = quadrant
        }
    }
}
