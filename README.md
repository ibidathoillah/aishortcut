# AIShortcut

A collection of scripts and tools for setting up AI-powered shortcuts and bots.

## Features

- **OpenCode + Telegram Bot Auto-Installer**: Quickly set up an OpenCode server and a Telegram bot interface.

## Usage

### One-Liner Installation (Recommended)

Run this command to download and execute the setup. This method is more reliable for `sudo` password prompts:

```bash
wget -qO setup.sh https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh && sudo bash setup.sh <TELEGRAM_BOT_TOKEN>
```

### Direct Pipe (Alternative)

If you have passwordless sudo configured:

```bash
curl -fsSL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh | sudo bash -s -- <TELEGRAM_BOT_TOKEN>
```

### Manual Repository Clone

### Manual Setup

- `<TELEGRAM_BOT_TOKEN>`: Your bot token from [@BotFather](https://t.me/BotFather).
- `[PORT]`: (Optional) Port for the OpenCode server (default: 4096).
