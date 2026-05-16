#!/bin/bash

# ============================================
# Codex + Telegram Auto-Installer
# Usage: ./setup-codex-telegram.sh <BOT_TOKEN> [CHAT_ID] [WORKSPACE_DIR] [CODEX_API_KEY]
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

BOT_TOKEN="${1:-}"
CHAT_ID="${2:-}"
WORKSPACE_DIR="${3:-$HOME/codex-workspace}"
CODEX_API_KEY="${4:-${CODEX_API_KEY:-}}"
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
echo -e "${BOLD}${GREEN}       Codex Telegram Auto-Installer         ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

if [ "$OS" != "Linux" ] && [ "$OS" != "Darwin" ]; then
  error "Unsupported OS: $OS"
fi

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
for cmd in curl git tar gzip unzip; do
  if command -v "$cmd" >/dev/null 2>&1; then
    substep "$cmd ... ok"
  else
    substep "$cmd ... missing"
    MISSING="$MISSING $cmd"
  fi
done

if [ -n "$MISSING" ]; then
  if [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      substep "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    substep "Installing missing packages via brew..."
    brew install $MISSING
  elif is_root; then
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

# --- Install Node.js 22+ ---
step "Installing Node.js 22+"
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -ge 22 ] 2>/dev/null; then
    success "  Already installed: $(node --version)"
  else
    substep "Node.js $(node --version) is too old. Upgrading to 22.x..."
    NODE_MAJOR=22
    if command -v apt-get >/dev/null 2>&1; then
      curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
      apt-get install -y -qq nodejs
    elif command -v dnf >/dev/null 2>&1; then
      curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
      dnf install -y nodejs
    elif command -v yum >/dev/null 2>&1; then
      curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
      yum install -y nodejs
    elif [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
      brew install node@22 || brew install node
    else
      error "Unsupported package manager. Install Node.js 22+ manually."
    fi
    success "  Installed: $(node --version)"
  fi
else
  substep "Installing Node.js 22..."
  NODE_MAJOR=22
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt-get install -y -qq nodejs
  elif command -v dnf >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    dnf install -y nodejs
  elif command -v yum >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    yum install -y nodejs
  elif [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    brew install node@22 || brew install node
  else
    error "Unsupported package manager. Install Node.js 22+ manually."
  fi
  success "  Installed: $(node --version)"
fi

# --- Install Codex CLI ---
step "Installing Codex CLI"
if command -v codex >/dev/null 2>&1; then
  success "  Already installed: $(codex --version 2>/dev/null || echo 'codex')"
else
  substep "Installing @openai/codex globally via npm..."
  npm_global_install @openai/codex || error "Codex CLI install failed."
  command -v codex >/dev/null 2>&1 || error "Codex CLI not found after install."
  success "  Installed: $(codex --version 2>/dev/null || echo 'codex')"
fi

if [ -z "$CODEX_API_KEY" ] && [ ! -d "$HOME/.codex" ]; then
  warn "No CODEX_API_KEY was provided and no $HOME/.codex auth directory was found."
  warn "The Telegram bridge supports /login, or you can run 'codex login' after setup."
fi

# --- Setup Codex Telegram Repo ---
if is_root && [ "$OS" = "Linux" ]; then
  INSTALL_DIR="/opt/codex-telegram"
else
  INSTALL_DIR="$HOME/codex-telegram"
fi

step "Setting up Codex Telegram repository"
if [ -d "$INSTALL_DIR/.git" ]; then
  substep "Directory exists, pulling latest..."
  cd "$INSTALL_DIR" || error "Could not enter $INSTALL_DIR"
  git remote set-url origin https://github.com/benedict2310/telecodex.git
  git fetch origin main && git reset --hard origin/main
else
  substep "Cloning repo..."
  git clone https://github.com/benedict2310/telecodex.git "$INSTALL_DIR"
  cd "$INSTALL_DIR" || error "Could not enter $INSTALL_DIR"
fi
ok

# --- Install Dependencies ---
step "Installing project dependencies"
npm install || error "npm install failed."
npm run build || error "Build failed."
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
  warn "  No message detected."
  echo -ne "${CYAN}  Enter your Telegram user ID manually: ${NC}"
  read -r CHAT_ID
  [ -z "$CHAT_ID" ] && error "Telegram user ID is required for TELEGRAM_ALLOWED_USER_IDS."
fi

case "$CHAT_ID" in
  ''|*[!0-9]*|0) error "Telegram user ID must be a positive integer." ;;
esac

# --- Environment File ---
step "Creating environment configuration"
mkdir -p "$WORKSPACE_DIR"
cat > "$WORKSPACE_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_ALLOWED_USER_IDS=$CHAT_ID
CODEX_API_KEY=$CODEX_API_KEY
CODEX_MODEL=
CODEX_SANDBOX_MODE=workspace-write
CODEX_APPROVAL_POLICY=never
CODEX_LAUNCH_PROFILES_JSON=
CODEX_DEFAULT_LAUNCH_PROFILE=default
ENABLE_UNSAFE_LAUNCH_PROFILES=false
TOOL_VERBOSITY=summary
SHOW_TURN_TOKEN_USAGE=false
MAX_FILE_SIZE=20971520
ENABLE_TELEGRAM_LOGIN=true
ENABLE_TELEGRAM_REACTIONS=false
OPENAI_API_KEY=
EOF
chmod 600 "$WORKSPACE_DIR/.env" || error "Could not secure $WORKSPACE_DIR/.env"
ok

# --- User helper ---
MANAGE_SCRIPT="$HOME/.codex-telegram-manage.sh"
cat > "$MANAGE_SCRIPT" <<EOF
#!/bin/bash
INSTALL_DIR="$INSTALL_DIR"
WORKSPACE_DIR="$WORKSPACE_DIR"
LOG_FILE="\$INSTALL_DIR/codex-telegram.log"
PID_FILE="\$INSTALL_DIR/codex-telegram.pid"

start() {
  if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
    echo "Codex Telegram already running (PID \$(cat "\$PID_FILE"))"
    exit 0
  fi
  cd "\$WORKSPACE_DIR" || exit 1
  nohup node "\$INSTALL_DIR/dist/index.js" >> "\$LOG_FILE" 2>&1 &
  echo \$! > "\$PID_FILE"
  echo "Codex Telegram started (PID \$!)"
}

stop() {
  if [ -f "\$PID_FILE" ]; then
    kill "\$(cat "\$PID_FILE")" 2>/dev/null || true
    rm -f "\$PID_FILE"
  fi
  echo "Codex Telegram stopped"
}

case "\${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  logs) tail -f "\$LOG_FILE" ;;
  status)
    if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
      echo "Codex Telegram running (PID \$(cat "\$PID_FILE"))"
    else
      echo "Codex Telegram stopped"
    fi
    ;;
  *) echo "Usage: \$0 {status|logs|stop|start|restart}"; exit 1 ;;
esac
EOF
chmod +x "$MANAGE_SCRIPT"

# --- Start Service ---
step "Starting Codex Telegram"
if can_use_systemd; then
  NODE_PATH=$(command -v node)
  SERVICE_USER="$(id -un)"
  SERVICE_HOME="$HOME"
  install_systemd_unit "codex-telegram.service" <<UNIT
[Unit]
Description=Codex Telegram Bot
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$WORKSPACE_DIR
Environment=NODE_ENV=production
Environment=HOME=$SERVICE_HOME
ExecStart=$NODE_PATH $INSTALL_DIR/dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  run_root_cmd systemctl daemon-reload || error "systemctl daemon-reload failed."
  run_root_cmd systemctl enable codex-telegram || error "Failed to enable codex-telegram."
  run_root_cmd systemctl restart codex-telegram || error "Failed to start codex-telegram. Run: journalctl -u codex-telegram -n 100"
  success "  Started via systemd."
else
  "$MANAGE_SCRIPT" restart
  success "  Started in background."
fi

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "  ${CYAN}Install${NC} : $INSTALL_DIR"
echo -e "  ${CYAN}Workspace${NC}: $WORKSPACE_DIR"
if can_use_systemd; then
  echo -e "  ${CYAN}Status${NC}  : systemctl status codex-telegram"
  echo -e "  ${CYAN}Logs${NC}    : journalctl -u codex-telegram -f"
  echo -e "  ${CYAN}Stop${NC}    : systemctl stop codex-telegram"
else
  echo -e "  ${CYAN}Status${NC}  : ~/.codex-telegram-manage.sh status"
  echo -e "  ${CYAN}Logs${NC}    : ~/.codex-telegram-manage.sh logs"
  echo -e "  ${CYAN}Stop${NC}    : ~/.codex-telegram-manage.sh stop"
fi
echo ""
