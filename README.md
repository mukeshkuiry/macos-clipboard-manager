# 📋 ClipBro (macOS Clipboard Manager)

ClipBro is a sleek, ultra-minimalist, zero-permission native macOS clipboard manager. It monitors your copying history and provides a system-wide search overlay instantly at your current mouse pointer position. 

Unlike other clipboard tools, **ClipBro is 100% compliant with restricted enterprise profiles (MDMs)** and does not require elevated macOS Accessibility or Input Monitoring privileges.

---

## ✨ Features
- **Zero-Permission Workaround:** Engineered using localized PID event targets to bypass restrictive Accessibility security blocks.
- **Spotlight-Style Search:** Press `Option + V` to show a beautiful, blurred frosted-glass panel centered at your current mouse cursor.
- **Ultra-Fast Real-Time Search:** Instantly matches history items in less than 2ms.
- **System-Wide Cycle HUD (`Option + C`):** Cycle through recent clips with a translucent card popup on the bottom of your screen.
- **Lightweight Native Core:** Built in raw Swift, consuming under 15MB of RAM at idle.
- **Quick Paste Keycombos:** Hit `Command + 1` through `Command + 9` to instantly select any of the top 9 history items.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| **`Option + V`** | Toggle Clipboard Search Overlay |
| **`Option + C`** | Cycle History Clipboard (HUD Indicator) |
| **`Up / Down Arrows`** | Navigate through history rows |
| **`Enter / Double-Click`** | Copy selected item to clipboard & close popup |
| **`Command + 1..9`** | Instantly Copy row index (1 to 9) and close |
| **`Escape`** | Close search overlay |

---

## 🚀 Installation

### Option A: Homebrew Tap (Recommended)
You can compile and register the ClipBro background daemon on-the-fly using Homebrew:

```bash
# 1. Tap our official Homebrew repository
brew tap mukeshkuiry/tap

# 2. Compile and install ClipBro on-the-fly
brew install clipboardmanager

# 3. Start the background service daemon automatically
brew services start clipboardmanager
```

---

### Option B: Local Manual Script
If you prefer to compile and install locally without using Homebrew:

```bash
# 1. Clone the repository and enter the directory
git clone https://github.com/mukeshkuiry/macos-clipboard-manager.git
cd macos-clipboard-manager

# 2. Run the local installer script
./install.sh
```

---

## 🛠️ Diagnostics & Customization

### Active Process Monitoring
Check if your background daemon is running smoothly:
```bash
ps aux | grep ClipboardManager
```

### Manual Service Controls (Local Script version)
- **Stop Service:** `launchctl unload ~/Library/LaunchAgents/com.user.clipboardmanager.plist`
- **Start Service:** `launchctl load ~/Library/LaunchAgents/com.user.clipboardmanager.plist`

### Customizing Keycombos & History
Configurations and histories are stored safely on your local disk at `~/.config/macos-clipboard-manager/`:
- **`config.json`:** Modify default trigger keycodes and modifier mappings.
- **`database.json`:** Flat-file clipboard history logs.

---

## 📄 License
This project is open-source and released under the MIT License. Created by **Mukesh Kuirky**.
