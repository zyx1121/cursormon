<!-- 翻译自 README.md @ docs/readme-template-v2。只翻译 "For AI agents" 之前的章节，英文版更新时一起改。 -->

<div align="center">

<h1>Cursormon</h1>

<p><strong>跟着 macOS 光标跑的一列像素宝可梦。</strong></p>

[![CI](https://img.shields.io/github/actions/workflow/status/zyx1121/cursormon/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/zyx1121/cursormon/actions)
[![Release](https://img.shields.io/github/v/release/zyx1121/cursormon?style=flat-square&sort=semver)](https://github.com/zyx1121/cursormon/releases)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple)](Package.swift)
[![License](https://img.shields.io/github/license/zyx1121/cursormon?style=flat-square)](LICENSE)

[English](README.md) | [繁體中文](README.zh-TW.md) | **简体中文**

</div>

桌面宠物通常是一个很大的置顶窗口，或是一个要求辅助功能权限的应用。Cursormon 两者都不需要。从菜单栏挑几只宝可梦，它们就会跟着光标在屏幕上跑。

## 功能

- **跟着光标走**：每只宠物会慢慢追上前面那一只，好几只就排成一列。
- **不需要任何权限**：只从点击穿透的面板读取 `NSEvent.mouseLocation`，macOS 不会要求辅助功能权限。
- **运行时才抓图**：从 PokeAPI 抓第五世代的动画图，第一次使用时缓存，不打包进应用。
- **动作自然**：移动时有走路动画，静止时慢慢呼吸，并转身面向移动的方向。
- **登录时启动**：菜单栏的开关会通过 `SMAppService` 注册。

## 快速开始

从 [最新 release](https://github.com/zyx1121/cursormon/releases/latest) 下载 `Cursormon-v0.1.0-macos.zip`，或自己构建：

```sh
git clone https://github.com/zyx1121/cursormon && cd cursormon
make run
```

菜单栏会出现 🐾 图标。第一次启动会下载需要的图，所以需要网络一次，之后就能离线使用。

## 使用方法

- 点 🐾 可以挑宠物、调大小和跟随距离、开关登录时启动，或退出程序。
- 运行 `make install` 把应用复制到 `/Applications`。登录时启动要应用放在那里，重启后才会生效。
- 要加新宠物，把全国图鉴编号和名字加进 `Sources/Cursormon/main.swift` 的 `SPECIES`，再运行 `make run`。

## 工作原理

每只宠物都是一个透明、点击穿透的 `NSPanel`，浮在所有窗口上面。`pet[0]` 跟着光标，`pet[i]` 跟着 `pet[i-1]`，最靠近光标的在最上层。ImageIO 解码 PokeAPI 的每张动画 GIF 并裁成刚好的大小，应用把原始 `.gif` 缓存在 `~/Library/Application Support/Cursormon/`。

## 限制

- 需要 macOS 14 以上。
- 每只宠物第一次出现时需要网络。

## 其他

给 AI agent 的结构化信息与开发说明见[英文版](README.md#for-ai-agents)。

## 免责声明

宝可梦的名称和图片是 Nintendo、Game Freak 和 The Pokémon Company 的商标。Cursormon 只在运行时抓取，从不重新分发。这是非商业的同人项目，与上述公司都没有关系。

## 许可证

[MIT](LICENSE)，仅适用于代码。
