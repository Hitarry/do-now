import SwiftUI

struct PinnedItemView: View {
    let itemId: UUID

    @Environment(TodoViewModel.self) private var viewModel
    @State private var breathOpacity: Double = 1.0

    var body: some View {
        let theme = ThemeConfig.config(for: viewModel.theme)
        let item = viewModel.findItem(itemId)

        HStack(spacing: 8) {
            // 方形完成框
            Button(action: {
                viewModel.toggleCompleted(itemId)
                viewModel.unpinItem()
            }) {
                Image(systemName: item?.isCompleted == true
                      ? "checkmark.square.fill"
                      : "square")
                    .font(.system(size: 16))
                    .foregroundColor(item?.isCompleted == true ? .green : theme.secondaryText)
            }
            .buttonStyle(.plain)

            // 标题（ZStack 隔离 opacity）
            ZStack {
                Text(item?.title.isEmpty == false ? item!.title : "（无标题）")
                    .font(pinDisplayFont(item: item))
                    .strikethrough(item?.isCompleted ?? false)
                    .foregroundColor(item?.isCompleted == true
                        ? theme.secondaryText
                        : (item?.textColor).flatMap { colorFromHex($0) } ?? theme.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .opacity(viewModel.isPinnedBreathingEnabled ? breathOpacity : 1.0)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 取消钉住（用圆形浅色背景保证透明背景下可见）
            Button(action: { viewModel.unpinItem() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 24, height: 24)
                    Image(systemName: "pin.slash")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .help("取消钉住")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(viewModel.theme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .padding(4)
        .onAppear {
            startBreathingIfEnabled()
        }
        .onChange(of: viewModel.isPinnedBreathingEnabled) { _, enabled in
            if enabled {
                startBreathingIfEnabled()
            } else {
                withAnimation(nil) { breathOpacity = 1.0 }
            }
        }
        .contextMenu {
            let vm = viewModel
            if vm.isPinnedBreathingEnabled {
                Button(action: { vm.isPinnedBreathingEnabled = false }) {
                    Label("呼吸效果", systemImage: "checkmark")
                }
            } else {
                Button(action: { vm.isPinnedBreathingEnabled = true }) {
                    Text("呼吸效果")
                }
            }
        }
    }

    private func startBreathingIfEnabled() {
        guard viewModel.isPinnedBreathingEnabled else { return }
        breathOpacity = 1.0
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathOpacity = 0.6
        }
    }

    private func pinDisplayFont(item: TodoItem?) -> Font {
        let size = item?.fontSize ?? 13
        var font = Font.system(size: size)
        if item?.isBold == true { font = font.bold() }
        if item?.isItalic == true { font = font.italic() }
        return font
    }
}
