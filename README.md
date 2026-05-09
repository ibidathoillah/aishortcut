# AIShortcut

A collection of scripts and tools for setting up AI-powered shortcuts and bots.

## Features

- **OpenCode + Telegram Bot Auto-Installer**: Quickly set up an OpenCode server and a Telegram bot interface.

## Usage

### One-Liner Installation (Recommended)

This command will download the script and start it. If you don't provide the token in the command, it will ask you for it interactively:

```bash
wget -qO setup.sh https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh && sudo bash setup.sh
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
