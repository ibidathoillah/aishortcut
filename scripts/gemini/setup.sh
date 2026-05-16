#!/bin/bash

# ============================================
# Gemini CLI + Telegram Bot Auto-Installer
# Deploy a Gemini AI server with Telegram bot frontend in one command
# Usage: ./setup-gemini-telegram.sh <BOT_TOKEN> [CHAT_ID]
# ============================================

GREEN='\033[0;32m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

info()    { echo -e "${CYAN}${NC}$1"; }
success() { echo -e "${GREEN}${NC}$1"; }
warn()    { echo -e "${YELLOW}${NC}$1"; }
error()   { echo -e "${RED}${NC}$1"; exit 1; }
step()    { echo -e "\n${BLUE}${BOLD}> ${1}${NC}"; }
substep() { echo -e "  ${NC}|- $1${NC}"; }
ok()      { echo -e "  ${GREEN}OK${NC}"; }
fail()    { echo -e "  ${RED}FAIL${NC}"; exit 1; }

BOT_TOKEN="${1:-}"
CHAT_ID="${2:-}"
OS="$(uname -s)"

is_root() { [ "$EUID" -eq 0 ]; }
run_root_cmd() {
  if is_root; then "$@"
  else sudo "$@"
  fi
}
can_use_systemd() {
  [ "$OS" = "Linux" ] && command -v systemctl >/dev/null 2>&1 && { is_root || command -v sudo >/dev/null 2>&1; }
}
install_systemd_unit() {
  local unit_name=$1
  local unit_file="/tmp/$unit_name.$$"
  cat > "$unit_file"
  run_root_cmd install -m 644 "$unit_file" "/etc/systemd/system/$unit_name" || error "Failed to install $unit_name. Check sudo permissions."
  rm -f "$unit_file"
}
npm_global_install() {
  npm install -g "$@" || {
    if ! is_root && command -v sudo >/dev/null 2>&1; then
      warn "npm global install failed. Retrying with sudo..."
      sudo npm install -g "$@"
    else
      return 1
    fi
  }
}

trap 'echo -e "\n  ${RED}Setup interrupted.${NC}"; exit 1' INT TERM

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  Gemini CLI + Telegram Bot Auto-Installer   ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

# --- Bot Token ---
if [ -z "$BOT_TOKEN" ]; then
  warn "No Telegram Bot Token provided."
  echo -ne "${CYAN}  Enter your Telegram Bot Token (from @BotFather): ${NC}"
  read -r BOT_TOKEN
  [ -z "$BOT_TOKEN" ] && error "Bot Token is required."
fi

# --- Install Prerequisites ---
step "Checking prerequisites"
MISSING=""
for cmd in curl git tar gzip unzip sudo; do
  if command -v "$cmd" >/dev/null 2>&1; then
    substep "$cmd ... ok"
  else
    substep "$cmd ... missing"
    MISSING="$MISSING $cmd"
  fi
done

if [ -n "$MISSING" ]; then
  if is_root; then
    if command -v apt-get >/dev/null 2>&1; then
      substep "Installing missing packages via apt..."
      apt-get update -qq && apt-get install -y -qq $MISSING
    elif command -v yum >/dev/null 2>&1; then
      substep "Installing missing packages via yum..."
      yum install -y -q $MISSING
    elif command -v apk >/dev/null 2>&1; then
      substep "Installing missing packages via apk..."
      apk add --quiet $MISSING
    elif command -v pacman >/dev/null 2>&1; then
      substep "Installing missing packages via pacman..."
      pacman -S --noconfirm $MISSING
    else
      error "No supported package manager found. Install manually: $MISSING"
    fi
  else
    warn "Missing commands: $MISSING"
    warn "Run as root or install manually: apt install$MISSING"
  fi
fi
ok

# --- Install Node.js 20+ ---
step "Installing Node.js 20+"
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -ge 20 ] 2>/dev/null; then
    success "  Already installed: $(node --version)"
  else
    substep "Node.js $(node --version) is too old. Upgrading to 20.x..."
    NODE_MAJOR=20
    if command -v apt-get >/dev/null 2>&1; then
      curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
      apt-get install -y -qq nodejs
    elif command -v dnf >/dev/null 2>&1; then
      curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
      dnf install -y nodejs
    elif command -v yum >/dev/null 2>&1; then
      curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
      yum install -y nodejs
    else
      error "Unsupported package manager. Install Node.js 20+ manually."
    fi
    success "  Installed: $(node --version)"
  fi
else
  substep "Installing Node.js 20..."
  NODE_MAJOR=20
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt-get install -y -qq nodejs
  elif command -v dnf >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    dnf install -y nodejs
  elif command -v yum >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    yum install -y nodejs
  else
    error "Unsupported package manager. Install Node.js 20+ manually."
  fi
  success "  Installed: $(node --version)"
fi

# --- Install gemini-cli-telegram ---
step "Installing gemini-cli-telegram"
if command -v gemini-cli-telegram >/dev/null 2>&1; then
  substep "Already installed. Checking for update..."
  npm update -g gemini-cli-telegram --legacy-peer-deps 2>/dev/null || true
  success "  $(gemini-cli-telegram --version 2>/dev/null || echo 'ready')"
else
  substep "Installing globally via npm..."
  npm_global_install gemini-cli-telegram --legacy-peer-deps || error "npm install failed."
  command -v gemini-cli-telegram >/dev/null 2>&1 || error "Installation failed."
  success "  Installed: $(gemini-cli-telegram --version 2>/dev/null || echo 'ready')"
fi

# --- Configuration ---
CONFIG_DIR="$HOME/.gemini-cli-telegram"
CONFIG_FILE="$CONFIG_DIR/config.json"

step "Configuring Telegram bot"

if [ -z "$CHAT_ID" ]; then
  echo -e "\n${BOLD}  Send a message to your bot on Telegram, then press Enter here.${NC}"
  read -r

  info "  Detecting chat ID..."
  for i in $(seq 1 10); do
    CHAT_ID=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
      | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    [ -n "$CHAT_ID" ] && break
    [ "$i" -lt 10 ] && substep "No messages yet, retrying in 3s... ($i/10)" && sleep 3
  done
fi

if [ -n "$CHAT_ID" ]; then
  success "  Chat ID: $CHAT_ID"
else
  warn "  No message detected."
  echo -ne "${CYAN}  Enter your Telegram user ID manually: ${NC}"
  read -r CHAT_ID
  [ -z "$CHAT_ID" ] && error "Telegram user ID is required."
fi

case "$CHAT_ID" in
  ''|*[!0-9]*|0) error "Telegram user ID must be a positive integer." ;;
esac

substep "Writing config to $CONFIG_FILE"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
{
  "telegramBotToken": "$BOT_TOKEN",
  "allowedUsers": [$CHAT_ID],
  "model": "gemini-2.5-pro"
}
EOF
chmod 600 "$CONFIG_FILE" || error "Could not secure $CONFIG_FILE"
ok

# --- Google Authentication ---
step "Google Authentication"
echo -e "  ${YELLOW}The setup wizard will now open for Google login.${NC}"
echo -e "  If already authenticated, you can skip this step.\n"

if command -v gemini-cli-telegram >/dev/null 2>&1; then
  # Check if already authenticated
  if [ -d "$HOME/.config/google-gemini-cli" ] && [ -n "$(ls -A "$HOME/.config/google-gemini-cli" 2>/dev/null)" ]; then
    substep "Existing Google credentials detected. Skipping auth."
    info "  To re-authenticate later: gemini-cli-telegram setup auth"
  else
    substep "Running Google authentication (follow prompts)..."

    # Try to open a real TTY for interactive input when piped
    if [ ! -t 0 ]; then
      exec < /dev/tty 2>/dev/null || true
    fi

    gemini-cli-telegram setup auth || warn "  Auth step may not have completed fully."
    substep "You can always re-run: gemini-cli-telegram setup auth"
  fi
fi
ok

# --- Systemd Service or daemon fallback ---
NODE_PATH=$(command -v node)
CLI_PATH=$(command -v gemini-cli-telegram)

step "Starting the bot"
if can_use_systemd; then
  substep "Creating systemd service..."
  SERVICE_USER="$(id -un)"
  SERVICE_HOME="$HOME"
  install_systemd_unit "gemini-telegram.service" <<UNIT
[Unit]
Description=Gemini CLI Telegram Bot
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Environment=HOME=$SERVICE_HOME
ExecStart=$NODE_PATH $CLI_PATH start --live
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  run_root_cmd systemctl daemon-reload || error "systemctl daemon-reload failed."
  run_root_cmd systemctl enable gemini-telegram || error "Failed to enable gemini-telegram."
  run_root_cmd systemctl restart gemini-telegram || error "Failed to start gemini-telegram. Run: journalctl -u gemini-telegram -n 100"
  success "  Started via systemd."
else
  substep "Starting in background..."
  gemini-cli-telegram stop 2>/dev/null || true
  gemini-cli-telegram start
  success "  Started via daemon."
fi

# --- Done ---
echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
if can_use_systemd; then
  echo -e "  ${CYAN}Status${NC} : systemctl status gemini-telegram"
  echo -e "  ${CYAN}Logs${NC}   : journalctl -u gemini-telegram -f"
  echo -e "  ${CYAN}Stop${NC}   : systemctl stop gemini-telegram"
else
  echo -e "  ${CYAN}Status${NC} : gemini-cli-telegram status"
  echo -e "  ${CYAN}Logs${NC}   : gemini-cli-telegram logs"
  echo -e "  ${CYAN}Stop${NC}   : gemini-cli-telegram stop"
fi
echo ""
