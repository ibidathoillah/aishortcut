#!/bin/bash
set -e

# ============================================
# OpenCode + Telegram Bot Auto-Installer
# Usage: ./setup-opencode-telegram.sh <BOT_TOKEN> [PORT] [CHAT_ID]
# ============================================

BOT_TOKEN="${1:-}"
PORT="${2:-4096}"
CHAT_ID="${3:-}"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo)."
  exit 1
fi

if [ -z "$BOT_TOKEN" ]; then
  echo "Usage: $0 <TELEGRAM_BOT_TOKEN> [PORT] [CHAT_ID]"
  echo "  TELEGRAM_BOT_TOKEN : from @BotFather"
  echo "  PORT               : opencode server port (default: 4096)"
  echo "  CHAT_ID            : (optional) your Telegram chat ID"
  exit 1
fi

echo "==> Installing OpenCode..."
if ! command -v opencode &>/dev/null; then
  curl -fsSL https://opencode.ai/install | bash
  export PATH="$HOME/.opencode/bin:$PATH"
fi
echo "OpenCode: $(opencode --version)"

echo "==> Installing Bun..."
if ! command -v bun &>/dev/null; then
  curl -fsSL https://bun.sh/install | bash
fi
export PATH="$HOME/.bun/bin:$PATH"
echo "Bun: $(bun --version)"

INSTALL_DIR="/opt/opencode-telegram-bot"

echo "==> Setting up Telegram bot at $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
  cd "$INSTALL_DIR"
  git pull 2>/dev/null || true
else
  git clone https://github.com/grinev/opencode-telegram-bot.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

echo "==> Installing dependencies..."
bun install --ignore-scripts 2>/dev/null
bun run build

echo "==> Creating systemd services..."

cat > /etc/systemd/system/opencode-server.service <<UNIT
[Unit]
Description=OpenCode Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$HOME/.opencode/bin/opencode serve --port $PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

echo "==> Starting OpenCode server..."
systemctl daemon-reload
systemctl enable opencode-server
systemctl start opencode-server
sleep 5

if [ -z "$CHAT_ID" ]; then
  echo ""
  echo "==> Send a message to your bot on Telegram, then press Enter..."
  read -r

  echo "==> Detecting your chat ID..."
  for i in $(seq 1 10); do
    CHAT_ID=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
      | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    if [ -n "$CHAT_ID" ]; then
      echo "Detected Chat ID: $CHAT_ID"
      break
    fi
    if [ "$i" -lt 10 ]; then
      echo "No messages yet, retrying in 3s... ($i/10)"
      sleep 3
    fi
  done
else
  echo "==> Using provided Chat ID: $CHAT_ID"
fi

if [ -z "$CHAT_ID" ]; then
  echo "Error: No message detected. Message your bot and re-run the script."
  exit 1
fi

echo "==> Creating .env..."
cat > "$INSTALL_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_ALLOWED_USER_ID=$CHAT_ID
OPENCODE_API_URL=http://127.0.0.1:$PORT
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_MODEL_PROVIDER=opencode
OPENCODE_MODEL_ID=big-pickle
LOG_LEVEL=info
EOF

cat > /etc/systemd/system/opencode-telegram.service <<UNIT
[Unit]
Description=OpenCode Telegram Bot
After=network.target opencode-server.service
Wants=opencode-server.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$HOME/.bun/bin/bun run start
Restart=always
RestartSec=10
Environment=TELEGRAM_BOT_TOKEN=$BOT_TOKEN
Environment=TELEGRAM_ALLOWED_USER_ID=$CHAT_ID
Environment=OPENCODE_API_URL=http://127.0.0.1:$PORT
Environment=OPENCODE_MODEL_PROVIDER=opencode
Environment=OPENCODE_MODEL_ID=big-pickle

[Install]
WantedBy=multi-user.target
UNIT

echo "==> Starting Telegram bot..."
systemctl daemon-reload
systemctl enable opencode-telegram
systemctl start opencode-telegram

echo ""
echo "==> Setup complete!"
echo "    OpenCode server  : http://127.0.0.1:$PORT"
echo "    Telegram bot     : running as service"
echo ""
echo "    Commands:"
echo "      systemctl status opencode-server"
echo "      systemctl status opencode-telegram"
echo "      journalctl -u opencode-telegram -f"
