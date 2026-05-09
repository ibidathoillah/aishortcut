# AIShortcut

A collection of scripts and tools for setting up AI-powered shortcuts and bots.

## Features

- **OpenCode + Telegram Bot Auto-Installer**: Quickly set up an OpenCode server and a Telegram bot interface.

## Usage

### Option 1: Standard Installation (Recommended)

```bash
wget -qO setup.sh https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh && sudo bash setup.sh
```

### Option 2: For Restricted Terminals (If Option 1 fails)

If you see an error like `sudo: a terminal is required`, switch to the root user first, then run the script:

1. **Become root:**
   ```bash
   sudo -i
   # OR if that fails:
   su -
   ```

2. **Run the script:**
   ```bash
   wget -qO setup.sh https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh && bash setup.sh
   ```

### Advanced Usage

You can also pass arguments directly:
```bash
sudo bash setup.sh <TELEGRAM_BOT_TOKEN> [PORT] [CHAT_ID]
```

### Manual Repository Clone

### Manual Setup

- `<TELEGRAM_BOT_TOKEN>`: Your bot token from [@BotFather](https://t.me/BotFather).
- `[PORT]`: (Optional) Port for the OpenCode server (default: 4096).
