# AIShortcut

One-command deploy scripts to run AI coding assistants via Telegram.

- **OpenCode** AI server + Telegram bot frontend
- **Gemini CLI** + Telegram bot frontend

---

## OpenCode + Telegram

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `PORT` | OpenCode server port (random if omitted) |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Source:** [`scripts/opencode/setup.sh`](scripts/opencode/setup.sh)

---

## Gemini CLI + Telegram

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Source:** [`scripts/gemini/setup.sh`](scripts/gemini/setup.sh)

---

## Termux (Android)

```bash
pkg install curl git -y
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram-termux.sh)
```

**Source:** [`scripts/gemini/setup-termux.sh`](scripts/gemini/setup-termux.sh)

---

## Project Structure

```
aishortcut/
├── setup-opencode-telegram.sh      # root forwarder
├── setup-gemini-telegram.sh        # root forwarder
├── setup-gemini-telegram-termux.sh # root forwarder
├── scripts/
│   ├── opencode/
│   │   └── setup.sh                # OpenCode + Telegram installer
│   └── gemini/
│       ├── setup.sh                # Gemini CLI + Telegram installer
│       └── setup-termux.sh         # Termux-optimized Gemini installer
├── docs/
│   └── index.html
├── README.md
└── .gitignore
```

## Manual Setup

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-*.sh scripts/*/setup*.sh
./scripts/opencode/setup.sh       # OpenCode + Telegram
./scripts/gemini/setup.sh         # Gemini + Telegram
./scripts/gemini/setup-termux.sh  # Gemini + Telegram (Termux)
```
