<div align="center">
  <img src="assets/icon.png" alt="icon" width="32" />
</div>

# GoldenDict Auto Search

Auto search selected word in GoldenDict by double-click or clipboard.

Authors: GLM-5🧙‍♂️, scillidan🤡

The icon is from [SimpleKeys](https://beamedeighth.itch.io/simplekeys-animated-pixel-keyboard-keys) by [beamedeighth](https://beamedeighth.itch.io/).

## Install

```sh
scoop bucket add pile https://github.com/scillidan/scoop-pile
scoop install pile/goldendict-auto-search
```

## Usage

1. Press `Ctrl+Alt+Shift+G` to bind a window
2. Double-click a word in the bound window
3. GoldenDict will automatically search the word in popup window

### Search Modes

Two independent modes, can both be on simultaneously:

- **DoubleClick** (default on): Double-click to select and search, no clipboard pollution, group: `default`
- **Clipboard** (default off): Auto-search when clipboard content changes, group: `translate`

Each mode uses its own dictionary group. Toggle each independently via tray menu
