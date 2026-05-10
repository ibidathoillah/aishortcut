#!/bin/bash

# ============================================
# Gemini CLI + Telegram Bot - Termux Edition
# Deploy a Gemini AI server with Telegram bot on Android (Termux)
# Usage: ./setup-gemini-telegram-termux.sh <BOT_TOKEN> [CHAT_ID]
# ============================================

GREEN='\033[0;32m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

info()    { echo -e "${CYAN}${NC}$1"; }
success() { echo -e "${GREEN}${NC}$1"; }
warn()    { echo -e "${YELLOW}${NC}$1"; }
error()   { echo -e "${RED}${NC}$1"; exit 1; }
step()    { echo -e "\n${BLUE}${BOLD}> ${1}${NC}"; }
substep() { echo -e "  ${NC}|- $1${NC}"; }

BOT_TOKEN="${1:-}"
CHAT_ID="${2:-}"

trap 'echo -e "\n  ${RED}Setup interrupted.${NC}"; exit 1' INT TERM

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  Gemini CLI + Telegram Bot - Termux Edition  ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

# --- Bot Token ---
if [ -z "$BOT_TOKEN" ]; then
  warn "No Telegram Bot Token provided."
  echo -ne "${CYAN}  Enter your Telegram Bot Token (from @BotFather): ${NC}"
  read -r BOT_TOKEN
  [ -z "$BOT_TOKEN" ] && error "Bot Token is required."
fi

# --- Update & Install Prerequisites ---
step "Updating Termux packages"
pkg update -y -qq 2>/dev/null || pkg update -y
ok

step "Installing prerequisites"
MISSING=""
for cmd in curl git tar gzip python3 make gcc; do
  if command -v "$cmd" >/dev/null 2>&1; then
    substep "$cmd ... ok"
  else
    substep "$cmd ... missing"
    MISSING="$MISSING $cmd"
  fi
done

substep "Installing build tools for native modules..."
pkg install -y binutils build-essential python nodejs 2>/dev/null || \
  pkg install -y binutils make gcc python nodejs
ok

# --- Install gemini-cli-telegram ---
step "Installing gemini-cli-telegram"
npm_cache_dir=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
substep "npm cache: $npm_cache_dir"

if command -v gemini-cli-telegram >/dev/null 2>&1; then
  substep "Already installed. Checking for update..."
  npm update -g gemini-cli-telegram --legacy-peer-deps 2>/dev/null || true
  success "  $(gemini-cli-telegram --version 2>/dev/null || echo 'ready')"
else
  substep "Installing globally via npm..."

  # Try normal install first; fall back to --ignore-scripts if native build fails
  if npm install -g gemini-cli-telegram --legacy-peer-deps 2>/dev/null; then
    success "  Installed with native modules."
  else
    substep "Native build failed. Retrying with --ignore-scripts..."
    npm install -g gemini-cli-telegram --legacy-peer-deps --ignore-scripts 2>/dev/null
  fi

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
  warn "  No message detected. You can whitelist your ID later."
  CHAT_ID="0"
fi

substep "Writing config to $CONFIG_FILE"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
{
  "telegramBotToken": "$BOT_TOKEN",
  "allowedUsers": [$CHAT_ID],
  "model": "gemini-2.5-pro"
}
EOF
ok

# --- Google Authentication ---
step "Google Authentication"
echo -e "  ${YELLOW}The setup wizard will now open for Google login.${NC}"
echo -e "  If already authenticated, you can skip this step.\n"

if command -v gemini-cli-telegram >/dev/null 2>&1; then
  if [ -d "$HOME/.config/google-gemini-cli" ] && [ -n "$(ls -A "$HOME/.config/google-gemini-cli" 2>/dev/null)" ]; then
    substep "Existing Google credentials detected. Skipping auth."
    info "  To re-authenticate later: gemini-cli-telegram setup auth"
  else
    substep "Running Google authentication (follow prompts)..."
    if [ ! -t 0 ]; then
      exec < /dev/tty 2>/dev/null || true
    fi
    gemini-cli-telegram setup auth || warn "  Auth step may not have completed fully."
    substep "You can always re-run: gemini-cli-telegram setup auth"
  fi
fi
ok

# --- Start Bot (nohup — systemd not available on Termux) ---
step "Starting the bot"

# Kill any existing instance
gemini-cli-telegram stop 2>/dev/null || true
sleep 1

# Start as background daemon
gemini-cli-telegram start 2>/dev/null || {
  substep "Daemon command not available, using nohup..."
  CLI_PATH=$(command -v gemini-cli-telegram)
  nohup "$CLI_PATH" start --live > "$HOME/gemini-telegram.log" 2>&1 &
  success "  Started in background (pid $!)."
}

# --- Create management script ---
MANAGE_SCRIPT="$HOME/.gemini-telegram-manage.sh"
substep "Creating management script at $MANAGE_SCRIPT"
cat > "$MANAGE_SCRIPT" <<'MANAGE'
#!/bin/bash
case "${1:-status}" in
  status)
    if pgrep -f "gemini-cli-telegram" >/dev/null 2>&1; then
      echo "Gemini Telegram Bot: RUNNING"
      pgrep -f "gemini-cli-telegram" | while read -r pid; do
        echo "  PID: $pid"
      done
    else
      echo "Gemini Telegram Bot: STOPPED"
    fi
    ;;
  start)
    nohup gemini-cli-telegram start --live > "$HOME/gemini-telegram.log" 2>&1 &
    echo "Started (pid $!)"
    ;;
  stop)
    gemini-cli-telegram stop 2>/dev/null
    pkill -f "gemini-cli-telegram" 2>/dev/null || true
    echo "Stopped."
    ;;
  logs)
    tail -f "$HOME/gemini-telegram.log" 2>/dev/null || echo "No log file found."
    ;;
  restart)
    $0 stop; sleep 1; $0 start
    ;;
  *)
    echo "Usage: $0 {status|start|stop|restart|logs}"
    ;;
esac
MANAGE
chmod +x "$MANAGE_SCRIPT"

# --- Termux:Boot support hint ---
if [ -d "$HOME/.termux/boot" ]; then
  substep "Termux:Boot directory found. Creating auto-start script..."
  cat > "$HOME/.termux/boot/gemini-telegram.sh" <<'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sleep 10
gemini-cli-telegram start --live > "$HOME/gemini-telegram.log" 2>&1 &
BOOT
  chmod +x "$HOME/.termux/boot/gemini-telegram.sh"
  success "  Auto-start enabled via Termux:Boot."
else
  substep "Tip: Install Termux:Boot from F-Droid for auto-start on device boot"
  info "  mkdir -p ~/.termux/boot"
fi

# --- Done ---
echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "  ${CYAN}Status${NC} : $MANAGE_SCRIPT status"
echo -e "  ${CYAN}Logs${NC}   : $MANAGE_SCRIPT logs"
echo -e "  ${CYAN}Stop${NC}   : $MANAGE_SCRIPT stop"
echo -e "  ${CYAN}Start${NC}  : $MANAGE_SCRIPT start"
echo -e "  ${CYAN}Restart${NC}: $MANAGE_SCRIPT restart"
echo ""
