import SwiftUI

struct PinnedItemView: View {
    let itemId: UUID

    @Environment(TodoViewModel.self) private var viewModel

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

            // 标题
            Text(item?.title.isEmpty == false ? item!.title : "（无标题）")
                .font(pinDisplayFont(item: item))
                .strikethrough(item?.isCompleted ?? false)
                .foregroundColor(item?.isCompleted == true
                    ? theme.secondaryText
                    : (item?.textColor).flatMap { colorFromHex($0) } ?? theme.primaryText)
                .lineLimit(3)
                .fixedSize(horizontal: true, vertical: false)

            // 取消钉住
            Button(action: { viewModel.unpinItem() }) {
                Image(systemName: "pin.slash")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
            }
            .buttonStyle(.plain)
            .help("取消钉住")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(4)
    }

    private func pinDisplayFont(item: TodoItem?) -> Font {
        let size = item?.fontSize ?? 13
        var font = Font.system(size: size)
        if item?.isBold == true { font = font.bold() }
        if item?.isItalic == true { font = font.italic() }
        return font
    }
}
