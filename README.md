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

---

## Termux (Android)

[`setup-gemini-telegram-termux.sh`](setup-gemini-telegram-termux.sh) — Termux-optimized deploy for Android.

```bash
pkg install curl git -y
bash <(curl -sfL https://raw.githubusercontent.com/ibidathoillah/aishortcut/main/setup-gemini-telegram-termux.sh)
```

The script installs `binutils`, `build-essential`, and `python` for native module compilation, then falls back to `--ignore-scripts` if compilation fails. Manages the bot via a helper script at `~/.gemini-telegram-manage.sh` since systemd is not available on Termux.

**Management:**
```bash
~/.gemini-telegram-manage.sh status   # check if running
~/.gemini-telegram-manage.sh logs     # tail log output
~/.gemini-telegram-manage.sh stop     # stop the bot
~/.gemini-telegram-manage.sh start    # start the bot
```

## Manual Setup

```bash
git clone https://github.com/ibidathoillah/aishortcut.git
cd aishortcut
chmod +x setup-*.sh
./setup-opencode-telegram.sh   # or ./setup-gemini-telegram.sh
```
