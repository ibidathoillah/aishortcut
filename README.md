# AIShortcut

One-command deploy scripts to run AI coding assistants via Telegram.

- **OpenCode** AI server + Telegram bot frontend
- **Gemini CLI** + Telegram bot frontend (Linux & Termux/Android)

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
| Root (systemd) | `systemctl status opencode-telegram` | `journalctl -u opencode-telegram -f` | `systemctl stop opencode-telegram` |
| User (nohup) | `pgrep -f "bun run start"` | `tail -f ~/opencode-telegram-bot/telegram-bot.log` | `pkill -f "bun run start"` |

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
| Root (systemd) | `systemctl status gemini-telegram` | `journalctl -u gemini-telegram -f` | `systemctl stop gemini-telegram` |
| User (daemon) | `gemini-cli-telegram status` | `gemini-cli-telegram logs` | `gemini-cli-telegram stop` |

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
```

---

## How They Work

All installers follow the same pattern:

1. Install prerequisites (curl, git, tar, etc.)
2. Install the AI runtime (OpenCode binary, or Gemini CLI via npm)
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
├── scripts/
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
```
