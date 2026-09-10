# 晨云待办 · ChenYun Todo

> 一款极简的桌面悬浮待办 —— 始终浮在屏幕角落，不打断你的工作流。
> A minimal floating to-do list that lives in the corner of your screen — capture tasks without breaking your flow.

## ✨ 功能特性 · Features

- 📌 **悬浮置顶** — 无边框毛玻璃面板，始终位于所有窗口之上，支持一键吸附左上/右上角
- 🪟 **Floating & Always-on-Top** — borderless frosted-glass panel, snaps to either top corner in one click
- 🖱️ **自由拖动与缩放** — 拖动标题栏移动，右下角手柄调整大小，位置和尺寸自动记忆
- 🎚️ **Drag & Resize** — move by the title bar, resize from the corner grip; size and position are remembered
- ✅ **一键完成** — 每条待办右侧圆形按钮，完成后变灰置底；悬停可删除，支持拖拽排序
- ☑️ **Complete / Reorder** — one-tap completion, completed items sink to the bottom; drag to reorder, hover to delete
- 🚩 **三级优先级** — 低 / 中 / 高，旗帜图标 + 高优先级加粗，重点事项一眼可见
- 🚩 **3-Level Priority** — Low / Medium / High flags; high-priority items are bolded in red
- ⏰ **定时提醒** — 年月日 + 时间自由输入，到点弹出系统通知并响铃（可选开关）
- ⏰ **Reminders** — pick any date & time; get a native system notification with optional sound
- 🎨 **10 种背景样式** — 自动毛玻璃、羊皮纸、白/黄/橙/蓝/绿/粉/紫/深色，透明度与字号可调
- 🎨 **10 Backgrounds** — frosted auto, parchment, 8 solid colors; adjustable opacity and font size
- 🔕 **托盘常驻** — 关闭面板不退出，点菜单栏/托盘图标随时唤回
- 🔕 **Lives in the Tray** — closing the window hides it; one click on the tray icon brings it back
- 🪶 **极致轻量** — 安装包约 3–5 MB，内存占用极低，秒开无卡顿
- 🪶 **Tiny & Fast** — 3–5 MB installer, minimal memory footprint, instant launch

<img width="722" height="962" alt="image" src="https://github.com/user-attachments/assets/0ce7c735-108e-4584-af3d-a174e52a09a2" />
<img width="734" height="966" alt="image" src="https://github.com/user-attachments/assets/f02f11aa-e2e7-4397-b4de-d576e572b566" />
<img width="732" height="964" alt="image" src="https://github.com/user-attachments/assets/8742b596-e4e9-4f0c-8bcd-3e29c23bfb13" />
<img width="734" height="960" alt="image" src="https://github.com/user-attachments/assets/9e4a19f2-694c-4c48-bbdb-46251625ee3b" />


## 💻 支持平台 · Platforms

| 平台 Platform | 安装包 Installer | 状态 Status |
|---|---|---|
| macOS (Apple Silicon) | `.dmg` | ✅ |
| Windows 10 / 11 (x64) | `.exe` (NSIS) | ✅ |

## 📥 下载安装 · Download

- **正式发布版**：见 [Releases](https://github.com/cy3329520/chenyun-todo/releases)（打 tag 后自动发布）
- **最新构建**：进入 [Actions](https://github.com/cy3329520/chenyun-todo/actions) → 选择最新一次「构建安装包」运行 → 页面底部 Artifacts 下载（需登录 GitHub）
  - `晨云待办-windows-latest` → 解压后得到 `*-setup.exe`，双击安装
  - `晨云待办-macos-latest` → 解压后得到 `.dmg`

> **macOS 提示**：首次打开如被拦截，请到「系统设置 → 隐私与安全性」点击「仍要打开」。
> **Windows 提示**：SmartScreen 如弹出警告，选择「更多信息 → 仍要运行」（应用未做商业代码签名，属正常现象）。

- **Releases**: see [Releases](https://github.com/cy3329520/chenyun-todo/releases).
- **Latest CI builds**: open [Actions](https://github.com/cy3329520/chenyun-todo/actions) → the latest “构建安装包” run → download from Artifacts at the bottom.
  - Windows: unzip `晨云待办-windows-latest`, run the `*-setup.exe`.
  - macOS: unzip `晨云待办-macos-latest`, open the `.dmg`.

## 🚀 本地开发 · Development

```bash
cd chenyun-todo
npm install

# 开发模式（热重载）
npm run dev

# 打包当前平台安装包
npm run build
```

**环境要求 / Requirements**：[Node.js](https://nodejs.org) 18+、[Rust](https://www.rust-lang.org/tools/install)（stable）。
Windows 打包还需 WebView2 Runtime（Win11 已内置）和 NSIS（Tauri 会自动下载）。

## 🛠️ 技术栈 · Tech Stack

- [Tauri v2](https://tauri.app)（Rust）— 跨平台桌面外壳，系统级 WebView，包体极小
- 原生 HTML / CSS / JS 前端，零框架依赖
- 数据本地存储（localStorage），不上传任何数据
- macOS 另有一份 SwiftUI 原生实现（`MinimalTodo/` 目录）

## 📄 许可 · License

MIT — 自由使用与修改。

---

*让待办轻如晨云。*
