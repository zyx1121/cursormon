<!-- 翻譯自 README.md @ docs/readme-template-v2。只翻 "For AI agents" 以上的章節，英文版更新時一起改。 -->

<div align="center">

<h1>Cursormon</h1>

<p><strong>跟著 macOS 游標跑的一列像素寶可夢。</strong></p>

[![CI](https://img.shields.io/github/actions/workflow/status/zyx1121/cursormon/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/zyx1121/cursormon/actions)
[![Release](https://img.shields.io/github/v/release/zyx1121/cursormon?style=flat-square&sort=semver)](https://github.com/zyx1121/cursormon/releases)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple)](Package.swift)
[![License](https://img.shields.io/github/license/zyx1121/cursormon?style=flat-square)](LICENSE)

[English](README.md) | **繁體中文** | [简体中文](README.zh-CN.md)

</div>

桌面寵物通常是一個很大的置頂視窗，或是一個要求輔助使用權限的 App。Cursormon 兩者都不需要。從選單列挑幾隻寶可夢，牠們就會跟著游標在螢幕上跑。

## 功能

- **跟著游標走**：每隻寵物會緩緩追上前面那一隻，好幾隻就排成一列。
- **不需要任何權限**：只從點擊穿透的面板讀取 `NSEvent.mouseLocation`，macOS 不會要求輔助使用權限。
- **執行時才抓圖**：從 PokeAPI 抓第五世代的動畫圖，第一次使用時快取，不打包進 App。
- **動作自然**：移動時有走路動畫，靜止時慢慢呼吸，並轉身面向移動的方向。
- **登入時啟動**：選單列的開關會透過 `SMAppService` 註冊。

## 快速開始

從 [最新 release](https://github.com/zyx1121/cursormon/releases/latest) 下載 `Cursormon-v0.1.0-macos.zip`，或自己建置：

```sh
git clone https://github.com/zyx1121/cursormon && cd cursormon
make run
```

選單列會出現 🐾 圖示。第一次啟動會下載需要的圖，所以需要網路一次，之後就能離線使用。

## 使用方式

- 點 🐾 可以挑寵物、調大小和跟隨距離、開關登入時啟動，或結束程式。
- 執行 `make install` 把 App 複製到 `/Applications`。登入時啟動要 App 放在那裡，重開機後才會生效。
- 要加新寵物，把全國圖鑑編號和名字加進 `Sources/Cursormon/main.swift` 的 `SPECIES`，再執行 `make run`。

## 運作方式

每隻寵物都是一個透明、點擊穿透的 `NSPanel`，浮在所有視窗上面。`pet[0]` 跟著游標，`pet[i]` 跟著 `pet[i-1]`，最靠近游標的在最上層。ImageIO 解碼 PokeAPI 的每張動畫 GIF 並裁成剛好的大小，App 把原始 `.gif` 快取在 `~/Library/Application Support/Cursormon/`。

## 限制

- 需要 macOS 14 以上。
- 每隻寵物第一次出現時需要網路。

## 其他

給 AI agent 的結構化資訊與開發說明在[英文版](README.md#for-ai-agents)。

## 免責聲明

寶可夢的名稱和圖片是 Nintendo、Game Freak 和 The Pokémon Company 的商標。Cursormon 只在執行時抓取，從不重新散布。這是非商業的同人專案，與上述公司都沒有關係。

## 授權

[MIT](LICENSE)，只適用於程式碼。
