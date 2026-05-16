# AIShortcut

One-command deploy scripts to run AI coding assistants via Telegram.

- **OpenCode** AI server + Telegram bot frontend
- **Gemini CLI** + Telegram bot frontend (Linux & Termux/Android)
- **Codex CLI** + Telegram bot frontend

---

## Codex CLI + Telegram

Deploys a Telegram bridge for the [OpenAI Codex CLI](https://github.com/openai/codex).

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

### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status codex-telegram` | `journalctl -u codex-telegram -f` | `systemctl stop codex-telegram` |
| Fallback (daemon) | `~/.codex-telegram-manage.sh status` | `~/.codex-telegram-manage.sh logs` | `~/.codex-telegram-manage.sh stop` |

---

## OpenCode + Telegram

Deploys an [OpenCode](https://github.com/anomalyco/opencode) AI server with a Telegram bot.

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `PORT` | OpenCode server port (random if omitted) |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Source:** [`scripts/opencode/setup.sh`](scripts/opencode/setup.sh)

### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status opencode-telegram-$PORT` | `journalctl -u opencode-telegram-$PORT -f` | `systemctl stop opencode-server-$PORT opencode-telegram-$PORT` |
| Fallback (nohup) | `pgrep -f "bun run start"` | `tail -f ~/opencode-telegram-bot-$PORT/telegram-bot.log` | `pkill -f "bun run start"` |

---

## Gemini CLI + Telegram (Linux)

Deploys [Gemini CLI](https://github.com/google-gemini/gemini-cli) with a Telegram bot frontend.

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Source:** [`scripts/gemini/setup.sh`](scripts/gemini/setup.sh)

### Management

| Mode | Status | Logs | Stop |
| :--- | :--- | :--- | :--- |
| Linux (systemd, root/sudo) | `systemctl status gemini-telegram` | `journalctl -u gemini-telegram -f` | `systemctl stop gemini-telegram` |
| Fallback (daemon) | `gemini-cli-telegram status` | `gemini-cli-telegram logs` | `gemini-cli-telegram stop` |

---

## Gemini CLI + Telegram (Termux/Android)

Termux-optimized deploy using [DioNanos/gemini-cli-termux](https://github.com/DioNanos/gemini-cli-termux) fork for Android ARM64.

```bash
pkg install curl git -y
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram-termux.sh)
```

**Source:** [`scripts/gemini/setup-termux.sh`](scripts/gemini/setup-termux.sh)

### Management

```bash
~/.gemini-telegram-manage.sh status   # check if running
~/.gemini-telegram-manage.sh logs     # tail log output
~/.gemini-telegram-manage.sh stop     # stop the bot
~/.gemini-telegram-manage.sh start    # start the bot
~/.gemini-telegram-manage.sh restart  # restart the bot
~/.gemini-telegram-manage.sh wake     # acquire wake lock
```

### Phantom Process Killer (Android 12+)

Android 12+ kills background processes exceeding 32 phantom processes. If the bot keeps dying:

1. **Wake lock** — script auto-acquires `termux-wake-lock` on start
2. **Battery** — set Termux to **Unrestricted** in Settings > Apps > Termux > Battery
3. **Disable phantom killer** via ADB, Termux (wireless ADB), or root:

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

## How They Work

All installers follow the same pattern:

1. Install prerequisites (curl, git, tar, etc.)
2. Install the AI runtime (OpenCode binary, Gemini CLI, or Codex CLI via npm)
3. Install & configure the Telegram bot
4. Set up process management (systemd, nohup, or built-in daemon)
5. Start both services

Termux variant additionally installs `@mmmbuto/gemini-cli-termux` — a Termux-optimized fork of Gemini CLI with Android ARM64 PTY support and `termux-open-url` auth integration.

---

## Project Structure

```
aishortcut/
├── setup-opencode-telegram.sh      # root forwarder → scripts/opencode/setup.sh
├── setup-gemini-telegram.sh        # root forwarder → scripts/gemini/setup.sh
├── setup-gemini-telegram-termux.sh # root forwarder → scripts/gemini/setup-termux.sh
├── setup-codex-telegram.sh         # root forwarder → scripts/codex/setup.sh
├── scripts/
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

## Manual Setup

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-*.sh scripts/*/setup*.sh
./scripts/opencode/setup.sh       # OpenCode + Telegram
./scripts/gemini/setup.sh         # Gemini + Telegram (Linux)
./scripts/gemini/setup-termux.sh  # Gemini + Telegram (Termux)
./scripts/codex/setup.sh          # Codex + Telegram
```
