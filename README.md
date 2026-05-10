# AIShortcut

One-command deploy scripts to run AI coding assistants via Telegram.

- **OpenCode** AI server + Telegram bot frontend
- **Gemini CLI** + Telegram bot frontend

---

## OpenCode + Telegram

[`setup-opencode-telegram.sh`](setup-opencode-telegram.sh) — Deploys an [OpenCode](https://github.com/anomalyco/opencode) AI server with a Telegram bot.

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-opencode-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `PORT` | OpenCode server port (random if omitted) |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Dual-Mode:**
| Feature | Root Mode | User Mode |
| :--- | :--- | :--- |
| Location | `/opt/opencode-telegram-bot` | `~/opencode-telegram-bot` |
| Process Manager | `systemd` | `nohup` |
| Boot Persistence | Yes | No |

**Management:**
```bash
# Root
systemctl status opencode-telegram
journalctl -u opencode-telegram -f

# User
tail -f ~/opencode-telegram-bot/telegram-bot.log
pkill -f "bun run start"
```

---

## Gemini CLI + Telegram

[`setup-gemini-telegram.sh`](setup-gemini-telegram.sh) — Deploys [Gemini CLI](https://github.com/google-gemini/gemini-cli) with a Telegram bot frontend.

```bash
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram.sh)
```

| Argument | Description |
| :--- | :--- |
| `BOT_TOKEN` | Telegram bot token from @BotFather |
| `CHAT_ID` | Your Telegram user ID (auto-detected) |

**Dual-Mode:**
| Feature | Root Mode | User Mode |
| :--- | :--- | :--- |
| Process Manager | `systemd` | Built-in daemon |
| Boot Persistence | Yes | No |

**Management:**
```bash
# Root
systemctl status gemini-telegram
journalctl -u gemini-telegram -f

# User
gemini-cli-telegram status
gemini-cli-telegram logs
gemini-cli-telegram stop
```

---

## Manual Setup

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-*.sh
./setup-opencode-telegram.sh   # or ./setup-gemini-telegram.sh
```
