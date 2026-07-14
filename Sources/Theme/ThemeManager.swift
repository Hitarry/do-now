import SwiftUI

enum ThemeType: String, CaseIterable, Codable {
    case system = "系统默认"
    case dark = "深邃黑色"

    var displayName: String { rawValue }

    var subtitle: String {
        switch self {
        case .system: return "纯白界面，经典 macOS 风格"
        case .dark: return "深色沉浸，减少视觉干扰"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - 主题视觉参数
struct ThemeConfig {
    let name: ThemeType

    let canvasBackground: Color
    let quadrantBackground: Color
    let listBackground: Color
    let headerOpacity: Double
    let dividerColor: Color
    let borderColor: Color
    let primaryText: Color
    let secondaryText: Color

    /// 标题栏颜色（基于象限，不随主题变化）
    func headerColor(for quadrant: Quadrant) -> Color {
        switch quadrant {
        case .urgentImportant: return Color(red: 0.85, green: 0.25, blue: 0.25)
        case .notUrgentImportant: return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .urgentNotImportant: return Color(red: 0.90, green: 0.60, blue: 0.15)
        case .notUrgentNotImportant: return Color(red: 0.30, green: 0.75, blue: 0.40)
        }
    }

    func headerBackground(for quadrant: Quadrant) -> Color {
        headerColor(for: quadrant).opacity(headerOpacity)
    }

    /// 菜单栏 popover 背景
    var menuBarBackground: Color {
        switch name {
        case .system: return Color(nsColor: .windowBackgroundColor)
        case .dark: return Color(red: 0.08, green: 0.08, blue: 0.10)
        }
    }

    static func config(for theme: ThemeType) -> ThemeConfig {
        switch theme {
        case .system:
            return ThemeConfig(
                name: .system,
                canvasBackground: Color(nsColor: .windowBackgroundColor),
                quadrantBackground: Color(nsColor: .controlBackgroundColor),
                listBackground: Color(nsColor: .controlBackgroundColor),
                headerOpacity: 0.2,
                dividerColor: .primary.opacity(0.1),
                borderColor: .primary.opacity(0.08),
                primaryText: .primary,
                secondaryText: .secondary
            )
        case .dark:
            return ThemeConfig(
                name: .dark,
                canvasBackground: Color(red: 0.06, green: 0.06, blue: 0.08),
                quadrantBackground: Color(red: 0.10, green: 0.10, blue: 0.13),
                listBackground: Color(red: 0.08, green: 0.08, blue: 0.11),
                headerOpacity: 0.35,
                dividerColor: .white.opacity(0.08),
                borderColor: .white.opacity(0.06),
                primaryText: .white.opacity(0.92),
                secondaryText: .white.opacity(0.55)
            )
        }
    }
}

// 保留兼容性
struct ThemeColors {
    static func headerColor(for quadrant: Quadrant) -> Color {
        ThemeConfig.config(for: .system).headerColor(for: quadrant)
    }
}
