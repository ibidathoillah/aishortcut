# AIShortcut

A collection of scripts and tools for setting up AI-powered shortcuts and bots. The main deliverable is a **bash auto-installer** that deploys an [OpenCode](https://github.com/anomalyco/opencode) AI server with a Telegram bot frontend on any Linux machine.

## The Installer

The [`setup-opencode-telegram.sh`](setup-opencode-telegram.sh) script automates the entire setup:

1. Installs prerequisites (curl, git, tar, gzip, unzip)
2. Downloads and installs the latest **OpenCode** binary (with architecture/AVX2 detection)
3. Installs **Bun** JavaScript runtime
4. Clones the [opencode-telegram-bot](https://github.com/ibidathoillah/opencode-telegram-bot) repository
5. Builds the bot and configures it with your Telegram token
6. Detects your Telegram chat ID
7. Starts both services (OpenCode server + Telegram bot)

### Quick Start

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh)
```

### With Arguments (skip prompts)

```bash
bash setup-opencode-telegram.sh <TELEGRAM_BOT_TOKEN> [PORT] [CHAT_ID]
```

### Dual-Mode Support

| Feature | Root Mode (with sudo) | User Mode (no sudo) |
| :--- | :--- | :--- |
| Install Path | `/opt/opencode-telegram-bot` | `~/opencode-telegram-bot` |
| Process Manager | `systemd` (boot persistence) | `nohup` (background) |
| Logs | `journalctl -u opencode-telegram` | `tail -f ~/opencode-telegram-bot/*.log` |

### Management

**Root (systemd):**
```bash
systemctl status opencode-telegram    # Check service status
journalctl -u opencode-telegram -f    # Follow logs
```

**User (nohup):**
```bash
tail -f ~/opencode-telegram-bot/telegram-bot.log  # Follow logs
pkill -f "bun run start"                          # Stop the bot
```

## Manual Setup

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-opencode-telegram.sh
./setup-opencode-telegram.sh
```
