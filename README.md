# Do Now

A macOS menu bar app for task management based on the **Eisenhower Matrix** (4-quadrant priority system). Stay focused on what matters.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- **4 Quadrants** — Urgent & Important, Not Urgent but Important, Urgent but Not Important, Not Urgent & Not Important
- **CRUD** — Create, edit, delete tasks with inline text editing
- **Subtasks** — One level of subtasks per task
- **Drag & Drop** — Move tasks between quadrants
- **Batch Operations** — Multi-select mode for batch complete / delete / move
- **Collapse Completed** — Hide completed tasks per quadrant
- **Pin to Screen** — Pin a task to a floating window that stays on top of all apps (including fullscreen)
- **Text Styling** — 49 preset colors, bold, italic, font size
- **Emoji Picker** — 300+ built-in emojis, insert with one click
- **Themes** — System Default / Dark mode
- **Launch at Login** — Auto start on login
- **Export & Backup** — Export to JSON/CSV, auto-backup with configurable interval and retention
- **Undo / Redo** — ⌘Z / ⇧⌘Z
- **Keyboard Shortcuts** — ⌘N, ⌘W, ⌘,, ⌘/

## Installation

1. Download `Do Now.dmg` from [Releases](https://github.com/your-username/do-now/releases)
2. Drag `Do Now.app` to Applications folder
3. Right-click → Open on first launch (ad-hoc signed)

### Build from Source

```bash
git clone https://github.com/your-username/do-now.git
cd do-now
# Option 1: Use build.sh (generates project + compiles + creates DMG)
./build.sh
# Option 2: Open in Xcode directly (Do Now.xcodeproj included)
open Do\ Now.xcodeproj
# Then Product → Build (⌘B)
```

**Requirements:** Xcode 15+ (macOS 14 SDK), on macOS 14.0+

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel (build with `ARCHS="arm64 x86_64"` for Intel support)

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘Z | Undo |
| ⇧⌘Z | Redo |
| ⌘N | New task in active quadrant |
| ⌘W | Close popover |
| ⌘, | Open settings |
| ⌘/ | Show help |

## Tips

- **Right-click** a record → Pin to screen (floating window stays on top of all apps)
- **Right-click** the menu bar icon → Quit
- **Drag** records between quadrants
- Press Fn to open macOS character picker for symbols

## License

MIT

## Support

If you find Do Now helpful, consider supporting its development:

- [爱发电](https://afdian.com) — 搜索 **Do Now** 或点击主页链接
- **微信打赏** — 扫 README 底部二维码（如有）

Your support helps cover developer costs and motivates continued improvement. Thank you! 🙌
