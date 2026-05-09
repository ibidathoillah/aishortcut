#!/bin/bash
set -e

# ============================================
# OpenCode + Telegram Bot Auto-Installer
# Usage: ./setup-opencode-telegram.sh <BOT_TOKEN> [PORT] [CHAT_ID]
# ============================================

# --- Colors and Formatting ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

info() { echo -e "${CYAN}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✖ Error:${NC} $1"; exit 1; }
step() { echo -e "\n${BLUE}${BOLD}▶ ${1}${NC}"; }
substep() { echo -e "  ${NC}└─ $1${NC}"; }

# --- Arguments ---
BOT_TOKEN="${1:-}"
PORT="${2:-4096}"
CHAT_ID="${3:-}"

# --- Prerequisites Check ---
if [ "$EUID" -ne 0 ]; then
  warn "This script usually requires root privileges to install services and write to /opt."
  warn "Continuing without root... some steps might fail."
fi

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  OpenCode + Telegram Bot Auto-Installer    ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

if [ -z "$BOT_TOKEN" ]; then
  warn "No Telegram Bot Token provided."
  echo -ne "${BOLD}${CYAN}▶ Please enter your Telegram Bot Token: ${NC}"
  read -r BOT_TOKEN
  if [ -z "$BOT_TOKEN" ]; then
    error "Bot Token is required to continue."
  fi
fi

# --- Install OpenCode ---
step "Installing OpenCode..."
if ! command -v opencode &>/dev/null; then
  substep "Downloading and installing..."
  curl -fsSL https://opencode.ai/install | bash > /dev/null 2>&1
  export PATH="$HOME/.opencode/bin:$PATH"
fi
success "OpenCode installed: $(opencode --version)"

# --- Install Bun ---
step "Installing Bun..."
if ! command -v bun &>/dev/null; then
  substep "Downloading and installing..."
  curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
fi
export PATH="$HOME/.bun/bin:$PATH"
success "Bun installed: $(bun --version)"

# --- Setup Telegram Bot Repo ---
INSTALL_DIR="/opt/opencode-telegram-bot"
step "Setting up Telegram bot repository..."
if [ -d "$INSTALL_DIR" ]; then
  substep "Directory exists. Pulling latest changes..."
  cd "$INSTALL_DIR"
  git pull > /dev/null 2>&1 || true
else
  substep "Cloning repository to $INSTALL_DIR..."
  git clone https://github.com/grinev/opencode-telegram-bot.git "$INSTALL_DIR" > /dev/null 2>&1
  cd "$INSTALL_DIR"
fi
success "Repository ready."

# --- Install Dependencies ---
step "Installing project dependencies..."
substep "Running bun install & build..."
bun install --ignore-scripts > /dev/null 2>&1
bun run build > /dev/null 2>&1
success "Dependencies installed."

# --- Systemd for OpenCode Server ---
step "Configuring OpenCode Server Service..."
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

systemctl daemon-reload
systemctl enable opencode-server > /dev/null 2>&1
systemctl start opencode-server
success "OpenCode server service configured and started."
substep "Waiting for server to initialize..."
sleep 5

# --- Chat ID Detection ---
step "Configuring Telegram Chat ID..."
if [ -z "$CHAT_ID" ]; then
  echo -e "\n${BOLD}${CYAN}  Please send a message to your bot on Telegram now.${NC}"
  echo -e "  Press ${BOLD}Enter${NC} here after you have sent the message..."
  read -r

  info "Detecting your chat ID..."
  for i in $(seq 1 10); do
    CHAT_ID=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
      | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    if [ -n "$CHAT_ID" ]; then
      success "Detected Chat ID: $CHAT_ID"
      break
    fi
    if [ "$i" -lt 10 ]; then
      substep "No messages yet, retrying in 3s... ($i/10)"
      sleep 3
    fi
  done
else
  info "Using provided Chat ID: $CHAT_ID"
fi

if [ -z "$CHAT_ID" ]; then
  error "No message detected. Please message your bot and re-run the script."
fi

# --- Environment File ---
step "Creating environment configuration..."
cat > "$INSTALL_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_ALLOWED_USER_ID=$CHAT_ID
OPENCODE_API_URL=http://127.0.0.1:$PORT
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_MODEL_PROVIDER=opencode
OPENCODE_MODEL_ID=big-pickle
LOG_LEVEL=info
EOF
success ".env file generated."

# --- Systemd for Telegram Bot ---
step "Configuring Telegram Bot Service..."
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

systemctl daemon-reload
systemctl enable opencode-telegram > /dev/null 2>&1
systemctl start opencode-telegram
success "Telegram bot service configured and started."

# --- Final Output ---
echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "  ${CYAN}OpenCode Server${NC} : http://127.0.0.1:$PORT"
echo -e "  ${CYAN}Telegram Bot${NC}    : Running as a system service"
echo -e ""
echo -e "${BOLD}Useful Commands:${NC}"
echo -e "  ${YELLOW}Check Server Status${NC} : systemctl status opencode-server"
echo -e "  ${YELLOW}Check Bot Status${NC}    : systemctl status opencode-telegram"
echo -e "  ${YELLOW}View Bot Logs${NC}       : journalctl -u opencode-telegram -f"
echo -e "\nEnjoy your AI assistant!\n"
