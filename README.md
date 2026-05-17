# AIShortcut

**Deploy AI Coding Assistants to Telegram with a Single Command.**

AI Shortcut provides streamlined, one-command deployment scripts to get your favorite AI coding assistants up and running as Telegram bots. Whether you're a developer looking for an on-the-go coding companion or an enthusiast eager to experiment, AIShortcut simplifies the setup process.

## ✨ Features

*   **Claude Code + Telegram:** Integrate the official Claude Code CLI with a Telegram bot frontend.
*   **Codex CLI + Telegram:** Bridge the OpenAI Codex CLI to your Telegram chats.
*   **OpenCode + Telegram:** Deploy an OpenCode AI server paired with a Telegram bot.
*   **Gemini CLI + Telegram (Linux & Termux/Android):** Get the Gemini CLI running as a Telegram bot on Linux or Termux-enabled Android devices.

---

## 🚀 Quick Start

To deploy any of the AI assistants, simply choose your desired setup script and run it in your terminal. For example, to set up Claude Code:

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-claude-telegram.sh)
```

Each script handles prerequisites, AI runtime installation, Telegram bot configuration, and process management.

---

## 🛠️ Supported AI Assistants

### Claude Code + Telegram

Integrates the official [Claude Code](https://docs.anthropic.com/en/docs/claude-code/setup) CLI with a Telegram bot.

**Installation:**

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-claude-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |
| `APPROVED_DIRECTORY` | Base directory Claude may access (defaults to `~`) |
| `ANTHROPIC_API_KEY` | Optional Anthropic API key; otherwise authenticate with `claude auth login` |
| `BOT_USERNAME` | Optional Telegram bot username; auto-detected via Telegram API |

**Source:** [`scripts/claude/setup.sh`](scripts/claude/setup.sh)

#### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status claude-telegram` | `journalctl -u claude-telegram -f` | `systemctl stop claude-telegram` |
| Fallback (daemon) | `~/.claude-telegram-manage.sh status` | `~/.claude-telegram-manage.sh logs` | `~/.claude-telegram-manage.sh stop` |

#### Authentication

If you do not pass `ANTHROPIC_API_KEY`, finish setup by authenticating Claude Code locally:

```bash
claude auth login
```

---

### Codex CLI + Telegram

Deploys a Telegram bridge for the [OpenAI Codex CLI](https://github.com/openai/codex).

**Installation:**

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-codex-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |
| `WORKSPACE_DIR` | Workspace directory for Codex sessions (defaults to `~/codex-workspace`) |
| `CODEX_API_KEY` | Optional Codex/OpenAI API key; otherwise use `codex login` or Telegram `/login` |

**Source:** [`scripts/codex/setup.sh`](scripts/codex/setup.sh)

#### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status codex-telegram` | `journalctl -u codex-telegram -f` | `systemctl stop codex-telegram` |
| Fallback (daemon) | `~/.codex-telegram-manage.sh status` | `~/.codex-telegram-manage.sh logs` | `~/.codex-telegram-manage.sh stop` |

---

### OpenCode + Telegram

Deploys an [OpenCode](https://github.com/anomalyco/opencode) AI server with a Telegram bot.

**Installation:**

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `PORT` | OpenCode server port (random if omitted) |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Source:** [`scripts/opencode/setup.sh`](scripts/opencode/setup.sh)

#### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status opencode-telegram-$PORT` | `journalctl -u opencode-telegram-$PORT -f` | `systemctl stop opencode-server-$PORT opencode-telegram-$PORT` |
| Fallback (nohup) | `pgrep -f "bun run start"` | `tail -f ~/opencode-telegram-bot-$PORT/telegram-bot.log` | `pkill -f "bun run start"` |

---

### Gemini CLI + Telegram (Linux)

Deploys [Gemini CLI](https://github.com/google-gemini/gemini-cli) with a Telegram bot frontend.

**Installation:**

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Source:** [`scripts/gemini/setup.sh`](scripts/gemini/setup.sh)

#### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status gemini-telegram` | `journalctl -u gemini-telegram -f` | `systemctl stop gemini-telegram` |
| Fallback (daemon) | `gemini-cli-telegram status` | `gemini-cli-telegram logs` | `gemini-cli-telegram stop` |

---

### Gemini CLI + Telegram (Termux/Android)

Termux-optimized deployment using [DioNanos/gemini-cli-termux](https://github.com/DioNanos/gemini-cli-termux), a fork optimized for Android ARM64.

**Installation:**

```bash
pkg install curl git -y
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram-termux.sh)
```

**Source:** [`scripts/gemini/setup-termux.sh`](scripts/gemini/setup-termux.sh)

#### Management

```bash
~/.gemini-telegram-manage.sh status   # check if running
~/.gemini-telegram-manage.sh logs     # tail log output
~/.gemini-telegram-manage.sh stop     # stop the bot
~/.gemini-telegram-manage.sh start    # start the bot
~/.gemini-telegram-manage.sh restart  # restart the bot
~/.gemini-telegram-manage.sh wake     # acquire wake lock
```

#### Phantom Process Killer (Android 12+)

Android 12+ may kill background processes. If your bot keeps dying, follow these steps:

1.  **Wake lock** — The script auto-acquires `termux-wake-lock` on start.
2.  **Battery Optimization** — Set Termux to **Unrestricted** in Settings > Apps > Termux > Battery.
3.  **Disable Phantom Killer** — Via ADB, Termux (wireless ADB), or root:

    ```bash
    # From Termux itself (wireless ADB):
    pkg install android-tools
    adb pair 192.168.1.x:PORT          # from Developer Options > Wireless debugging
    adb connect 192.168.1.x:PORT
    adb shell device_config set_sync_disabled_for_tests persistent
    adb shell device_config put activity_manager max_phantom_processes 2147483647
    adb shell settings put global settings_enable_monitor_phantom_procs false

    # Root alternative (directly in Termux):
    su -c /system/bin/device_config set_sync_disabled_for_tests persistent
    su -c /system/bin/device_config put activity_manager max_phantom_processes 2147483647
    su -c setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false
    ```

    Reference: [atamshkai/Phantom-Process-Killer](https://github.com/atamshkai/Phantom-Process-Killer)

---

## ⚙️ How It Works

All installers follow the same pattern:

1.  Install prerequisites (curl, git, tar, etc.)
2.  Install the AI runtime (Claude Code, OpenCode, Gemini CLI, or Codex CLI)
3.  Install & configure the Telegram bot
4.  Set up process management (systemd, nohup, or built-in daemon)
5.  Start both services

The Termux variant additionally installs `@mmmbuto/gemini-cli-termux` — a Termux-optimized fork of Gemini CLI with Android ARM64 PTY support and `termux-open-url` authentication integration.

---

## 📂 Project Structure

```
aishortcut/
├── setup-claude-telegram.sh        # root forwarder → scripts/claude/setup.sh
├── setup-opencode-telegram.sh      # root forwarder → scripts/opencode/setup.sh
├── setup-gemini-telegram.sh        # root forwarder → scripts/gemini/setup.sh
├── setup-gemini-telegram-termux.sh # root forwarder → scripts/gemini/setup-termux.sh
├── setup-codex-telegram.sh         # root forwarder → scripts/codex/setup.sh
├── scripts/
│   ├── claude/
│   │   └── setup.sh                # Claude Code + Telegram installer
│   ├── codex/
│   │   └── setup.sh                # Codex + Telegram installer
│   ├── opencode/
│   │   └── setup.sh                # OpenCode + Telegram installer
│   └── gemini/
│       ├── setup.sh                # Gemini CLI + Telegram installer (Linux)
│       └── setup-termux.sh         # Termux-optimized Gemini installer
├── docs/
│   └── index.html                  # GitHub Pages site
├── README.md
└── .gitignore
```

---

## Manual Setup

If you prefer to clone the repository and run scripts locally:

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-*.sh scripts/*/setup*.sh
./scripts/claude/setup.sh         # Claude Code + Telegram
./scripts/opencode/setup.sh       # OpenCode + Telegram
./scripts/gemini/setup.sh         # Gemini + Telegram (Linux)
./scripts/gemini/setup-termux.sh  # Gemini + Telegram (Termux)
./scripts/codex/setup.sh          # Codex + Telegram
```
