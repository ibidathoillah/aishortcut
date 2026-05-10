#!/bin/bash

# ============================================
# OpenCode + Telegram Bot Auto-Installer
# Usage: ./setup-opencode-telegram.sh <BOT_TOKEN> [PORT] [CHAT_ID]
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
PORT="${2:-}"
CHAT_ID="${3:-}"

is_root() { [ "$EUID" -eq 0 ]; }

[ -z "$PORT" ] && PORT=$((RANDOM % 64511 + 1024))

trap 'echo -e "\n  ${RED}Setup interrupted.${NC}"; exit 1' INT TERM

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  OpenCode + Telegram Bot Auto-Installer    ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

if [ -z "$BOT_TOKEN" ]; then
  warn "No Telegram Bot Token provided."
  echo -ne "${CYAN}  Enter your Telegram Bot Token: ${NC}"
  read -r BOT_TOKEN
  [ -z "$BOT_TOKEN" ] && error "Bot Token is required."
fi

# --- Install Prerequisites ---
step "Checking prerequisites"
MISSING=""
for cmd in curl git tar gzip; do
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

# --- Install OpenCode ---
step "Installing OpenCode"
if command -v opencode >/dev/null 2>&1; then
  success "  Already installed: $(opencode --version)"
else
  substep "Detecting latest version..."
  VERSION=$(curl -sfL https://api.github.com/repos/anomalyco/opencode/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
  [ -z "$VERSION" ] && error "Could not fetch latest OpenCode version."

  raw_arch=$(uname -m)
  case "$raw_arch" in
    x86_64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) error "Unsupported architecture: $raw_arch" ;;
  esac

  # Check AVX2 for baseline variant
  needs_baseline=false
  if [ "$arch" = "x64" ] && ! grep -qi avx2 /proc/cpuinfo 2>/dev/null; then
    needs_baseline=true
  fi
  target="$arch"
  if [ "$needs_baseline" = "true" ]; then target="$target-baseline"; fi

  filename="opencode-linux-$target.tar.gz"
  url="https://github.com/anomalyco/opencode/releases/download/v$VERSION/$filename"
  tmpdir=$(mktemp -d)

  substep "Downloading v$VERSION ($target) ..."
  curl -fSL -o "$tmpdir/$filename" "$url" || error "Download failed for $filename"

  substep "Extracting..."
  tar -xzf "$tmpdir/$filename" -C "$tmpdir" || error "Extraction failed."
  mkdir -p "$HOME/.opencode/bin"
  mv "$tmpdir/opencode" "$HOME/.opencode/bin/" || error "Move failed."
  rm -rf "$tmpdir"

  export PATH="$HOME/.opencode/bin:$PATH"
  command -v opencode >/dev/null 2>&1 || error "OpenCode installation failed."
  success "  Installed: $(opencode --version)"
fi

# --- Install Bun ---
step "Installing Bun"
if command -v bun >/dev/null 2>&1; then
  success "  Already installed: $(bun --version)"
else
  substep "Downloading and installing..."
  curl -fsSL https://bun.sh/install | bash
  echo ""
  export PATH="$HOME/.bun/bin:$PATH"
  command -v bun >/dev/null 2>&1 || error "Bun installation failed."
  success "  Installed: $(bun --version)"
fi

# --- Setup Telegram Bot Repo ---
if is_root; then
  INSTALL_DIR="/opt/opencode-telegram-bot"
else
  INSTALL_DIR="$HOME/opencode-telegram-bot"
fi

step "Setting up Telegram bot repository"
if [ -d "$INSTALL_DIR" ]; then
  substep "Directory exists at $INSTALL_DIR"
  if is_root; then
    systemctl stop opencode-telegram opencode-server 2>/dev/null || true
  else
    pkill -f "bun run start" 2>/dev/null || true
    pkill -f "opencode serve" 2>/dev/null || true
    sleep 1
  fi
  substep "Pulling latest changes..."
  cd "$INSTALL_DIR"
  git remote set-url origin https://github.com/ibidathoillah/opencode-telegram-bot.git
  git fetch origin main
  git reset --hard origin/main
else
  substep "Cloning to $INSTALL_DIR ..."
  git clone https://github.com/ibidathoillah/opencode-telegram-bot.git "$INSTALL_DIR"
  cd "$INSTALL_DIR" || error "Could not enter $INSTALL_DIR"
fi
ok

# --- Install Dependencies ---
step "Installing project dependencies"
substep "bun install..."
bun install --ignore-scripts || error "bun install failed."
substep "bun run build..."
bun run build || error "bun run build failed."
ok

# --- Chat ID Detection ---
step "Configuring Telegram Chat ID"
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
  warn "  No message detected. Using placeholder."
  CHAT_ID="00000000"
fi

# --- Environment File ---
step "Creating environment configuration"
cat > "$INSTALL_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_ALLOWED_USER_ID=$CHAT_ID
OPENCODE_API_URL=http://127.0.0.1:$PORT
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_MODEL_PROVIDER=opencode
OPENCODE_MODEL_ID=big-pickle
LOG_LEVEL=info
EOF
ok

# --- Start OpenCode Server ---
step "Starting OpenCode Server"
if is_root; then
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
  systemctl enable opencode-server
  systemctl restart opencode-server
  success "  Started via systemd (port $PORT)."
else
  nohup opencode serve --port "$PORT" > "$INSTALL_DIR/opencode-server.log" 2>&1 &
  success "  Started in background (port $PORT, pid $!)."
fi

# --- Start Telegram Bot ---
step "Starting Telegram Bot"
if is_root; then
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

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable opencode-telegram
  systemctl restart opencode-telegram
  success "  Started via systemd."
else
  cd "$INSTALL_DIR"
  nohup bun run start > "$INSTALL_DIR/telegram-bot.log" 2>&1 &
  success "  Started in background (pid $!)."
fi

# --- Done ---
echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "  ${CYAN}OpenCode${NC} : http://127.0.0.1:$PORT"
if is_root; then
  echo -e "  ${CYAN}Status${NC}   : systemctl status opencode-telegram"
else
  echo -e "  ${CYAN}Logs${NC}     : tail -f $INSTALL_DIR/telegram-bot.log"
fi
echo ""
