# AIShortcut

A collection of scripts and tools for setting up AI-powered shortcuts and bots.

## Features

- **OpenCode + Telegram Bot Auto-Installer**: Quickly set up an OpenCode server and a Telegram bot interface.
- **Dual-Mode Support**: Works on full servers (Root/Systemd) and restricted environments (User/Nohup).
- **Interactive Setup**: Prompts for required tokens if not provided.
- **Beautiful CLI**: Color-coded output for better readability.

## Installation

Run this command to download and start the setup:

```bash
wget -qO setup.sh https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh && bash setup.sh
```

### How it works:

The script automatically detects your environment:

| Feature | Root Mode (with sudo) | User Mode (no sudo) |
| :--- | :--- | :--- |
| **Install Path** | `/opt/opencode-telegram-bot` | `~/opencode-telegram-bot` |
| **Process Manager** | `systemd` (Automatic) | `nohup` (Background) |
| **Logs** | `journalctl -u opencode-telegram` | `tail -f ~/opencode-telegram-bot/*.log` |
| **Persistence** | Starts on boot | Runs until killed/reboot |

---

### Advanced Usage

You can pass arguments directly to skip the interactive prompts:
```bash
bash setup.sh <TELEGRAM_BOT_TOKEN> [PORT] [CHAT_ID]
```

### Management Commands

#### Root Mode
```bash
# Check status
systemctl status opencode-telegram

# View logs
journalctl -u opencode-telegram -f
```

#### User Mode
```bash
# View logs
tail -f ~/opencode-telegram-bot/telegram-bot.log

# Stop the bot
pkill -f "bun run start"
```

## Manual Setup
If you prefer to manage the repository manually:

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-opencode-telegram.sh
./setup-opencode-telegram.sh
```
