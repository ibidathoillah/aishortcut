#!/bin/bash

# ============================================
# Claude Code + Telegram Auto-Installer
# Usage: ./setup-claude-telegram.sh <BOT_TOKEN> [CHAT_ID] [APPROVED_DIRECTORY] [ANTHROPIC_API_KEY] [BOT_USERNAME]
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
APPROVED_DIRECTORY="${3:-$HOME}"
ANTHROPIC_API_KEY="${4:-${ANTHROPIC_API_KEY:-}}"
BOT_USERNAME="${5:-}"
OS="$(uname -s)"
CLAUDE_TELEGRAM_REPO="https://github.com/RichardAtCT/claude-code-telegram.git"
CLAUDE_TELEGRAM_REF="${CLAUDE_TELEGRAM_REF:-latest}"

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
fetch_latest_release_tag() {
  curl -fsSL "https://api.github.com/repos/RichardAtCT/claude-code-telegram/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
}
git_worktree_clean() {
  git diff --quiet --ignore-submodules -- && git diff --cached --quiet --ignore-submodules --
}
dotenv_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//\$/\\$}
  printf '"%s"' "$value"
}
write_env_line() {
  printf '%s=%s\n' "$1" "$(dotenv_escape "$2")"
}
validate_chat_id_list() {
  case "$1" in
    ''|*[!0-9,]*|,*|*,,*|*,) return 1 ;;
    *) return 0 ;;
  esac
}

trap 'echo -e "\n  ${RED}Setup interrupted.${NC}"; exit 1' INT TERM

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}   Claude Code Telegram Auto-Installer      ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

if [ "$OS" != "Linux" ] && [ "$OS" != "Darwin" ]; then
  error "Unsupported OS: $OS"
fi

if [ -z "$BOT_TOKEN" ]; then
  warn "No Telegram Bot Token provided."
  echo -ne "${CYAN}  Enter your Telegram Bot Token (from @BotFather): ${NC}"
  read -r BOT_TOKEN
  [ -z "$BOT_TOKEN" ] && error "Bot Token is required."
fi

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

if command -v python3 >/dev/null 2>&1; then
  substep "python3 ... ok"
else
  substep "python3 ... missing"
  MISSING="$MISSING python3"
fi

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
      apt-get update -qq && apt-get install -y -qq $MISSING python3-venv
    elif command -v yum >/dev/null 2>&1; then
      substep "Installing missing packages via yum..."
      yum install -y -q $MISSING
    elif command -v dnf >/dev/null 2>&1; then
      substep "Installing missing packages via dnf..."
      dnf install -y $MISSING
    elif command -v apk >/dev/null 2>&1; then
      substep "Installing missing packages via apk..."
      apk add --quiet $MISSING py3-virtualenv
    elif command -v pacman >/dev/null 2>&1; then
      substep "Installing missing packages via pacman..."
      pacman -S --noconfirm $MISSING python python-virtualenv
    else
      error "No supported package manager found. Install manually: $MISSING"
    fi
  else
    warn "Missing commands: $MISSING"
    warn "Run as root or install manually before continuing."
  fi
fi
ok

step "Checking Python 3.11+"
PYTHON_BIN="$(command -v python3 || true)"
[ -n "$PYTHON_BIN" ] || error "python3 is required."
PYTHON_VERSION="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)"
PYTHON_MAJOR="$(echo "$PYTHON_VERSION" | cut -d. -f1)"
PYTHON_MINOR="$(echo "$PYTHON_VERSION" | cut -d. -f2)"
if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 11 ]; }; then
  error "Python 3.11+ is required. Found: $PYTHON_VERSION"
fi
success "  Python $PYTHON_VERSION"

step "Installing Node.js 18+"
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -ge 18 ] 2>/dev/null; then
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
      error "Unsupported package manager. Install Node.js 18+ manually."
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
    error "Unsupported package manager. Install Node.js 18+ manually."
  fi
  success "  Installed: $(node --version)"
fi

step "Installing Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
  success "  Already installed: $(claude --version 2>/dev/null || echo 'claude')"
else
  substep "Installing @anthropic-ai/claude-code globally via npm..."
  npm_global_install @anthropic-ai/claude-code || error "Claude Code CLI install failed."
  command -v claude >/dev/null 2>&1 || error "Claude CLI not found after install."
  success "  Installed: $(claude --version 2>/dev/null || echo 'claude')"
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  warn "No ANTHROPIC_API_KEY was provided."
  warn "You can authenticate Claude Code later with 'claude auth login'."
fi

if is_root && [ "$OS" = "Linux" ]; then
  INSTALL_DIR="/opt/claude-telegram"
else
  INSTALL_DIR="$HOME/claude-telegram"
fi

step "Setting up Claude Telegram repository"
if [ "$CLAUDE_TELEGRAM_REF" = "latest" ]; then
  RESOLVED_REF="$(fetch_latest_release_tag)"
  if [ -n "$RESOLVED_REF" ]; then
    substep "Latest stable release: $RESOLVED_REF"
  else
    RESOLVED_REF="main"
    warn "Could not resolve the latest GitHub release. Falling back to main."
  fi
else
  RESOLVED_REF="$CLAUDE_TELEGRAM_REF"
  substep "Requested ref: $RESOLVED_REF"
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  substep "Directory exists, updating repository..."
  cd "$INSTALL_DIR" || error "Could not enter $INSTALL_DIR"
  if ! git_worktree_clean; then
    error "Local changes detected in $INSTALL_DIR. Resolve or back them up before rerunning the installer."
  fi
  git remote set-url origin "$CLAUDE_TELEGRAM_REPO"
  git fetch origin --tags --prune || error "git fetch failed."
else
  substep "Cloning repo..."
  git clone "$CLAUDE_TELEGRAM_REPO" "$INSTALL_DIR" || error "git clone failed."
  cd "$INSTALL_DIR" || error "Could not enter $INSTALL_DIR"
fi

if git rev-parse -q --verify "refs/tags/$RESOLVED_REF" >/dev/null 2>&1; then
  git checkout --detach "tags/$RESOLVED_REF" || error "Failed to checkout release tag $RESOLVED_REF."
elif git show-ref --verify --quiet "refs/remotes/origin/$RESOLVED_REF"; then
  git checkout -B "$RESOLVED_REF" "origin/$RESOLVED_REF" || error "Failed to checkout branch $RESOLVED_REF."
else
  error "Could not find ref '$RESOLVED_REF' in the Claude Telegram repository."
fi
ok

step "Installing Python environment"
"$PYTHON_BIN" -m venv "$INSTALL_DIR/.venv" || error "Failed to create virtual environment."
"$INSTALL_DIR/.venv/bin/pip" install --upgrade pip setuptools wheel || error "pip bootstrap failed."
"$INSTALL_DIR/.venv/bin/pip" install . || error "Python package install failed."
mkdir -p "$INSTALL_DIR/data" || error "Could not create data directory."
ok

step "Configuring Telegram bot"
if [ -z "$BOT_USERNAME" ]; then
  BOT_USERNAME=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | sed -n 's/.*"username":"\([^"]*\)".*/\1/p')
fi

if [ -n "$BOT_USERNAME" ]; then
  success "  Bot username: @$BOT_USERNAME"
else
  warn "  Could not detect bot username automatically."
  echo -ne "${CYAN}  Enter your bot username (without @): ${NC}"
  read -r BOT_USERNAME
  [ -z "$BOT_USERNAME" ] && error "Bot username is required."
fi

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
  [ -z "$CHAT_ID" ] && error "Telegram user ID is required for ALLOWED_USERS."
fi

validate_chat_id_list "$CHAT_ID" || error "Telegram user ID must be a positive integer or comma-separated list of integers."

mkdir -p "$APPROVED_DIRECTORY" || error "Could not create approved directory: $APPROVED_DIRECTORY"
APPROVED_DIRECTORY="$(cd "$APPROVED_DIRECTORY" && pwd -P)" || error "Could not resolve approved directory."

step "Creating environment configuration"
{
  write_env_line "TELEGRAM_BOT_TOKEN" "$BOT_TOKEN"
  write_env_line "TELEGRAM_BOT_USERNAME" "$BOT_USERNAME"
  write_env_line "APPROVED_DIRECTORY" "$APPROVED_DIRECTORY"
  write_env_line "ALLOWED_USERS" "$CHAT_ID"
  write_env_line "ENABLE_TOKEN_AUTH" "false"
  write_env_line "AUTH_TOKEN_SECRET" ""
  write_env_line "DISABLE_SECURITY_PATTERNS" "false"
  write_env_line "DISABLE_TOOL_VALIDATION" "false"
  write_env_line "USE_SDK" "true"
  write_env_line "ANTHROPIC_API_KEY" "$ANTHROPIC_API_KEY"
  write_env_line "CLAUDE_CLI_PATH" "$(command -v claude)"
  write_env_line "CLAUDE_MAX_TURNS" "10"
  write_env_line "CLAUDE_TIMEOUT_SECONDS" "300"
  write_env_line "CLAUDE_MAX_COST_PER_USER" "10.0"
  write_env_line "CLAUDE_MAX_COST_PER_REQUEST" "5.0"
  write_env_line "CLAUDE_ALLOWED_TOOLS" "Read,Write,Edit,Bash,Glob,Grep,LS,Task,TaskOutput,MultiEdit,NotebookRead,NotebookEdit,WebFetch,TodoRead,TodoWrite,WebSearch,Skill,AskUserQuestion,EnterPlanMode,ExitPlanMode"
  write_env_line "AGENTIC_MODE" "true"
  write_env_line "VERBOSE_LEVEL" "1"
  write_env_line "RATE_LIMIT_REQUESTS" "10"
  write_env_line "RATE_LIMIT_WINDOW" "60"
  write_env_line "RATE_LIMIT_BURST" "20"
  write_env_line "DATABASE_URL" "sqlite:///data/bot.db"
  write_env_line "SESSION_TIMEOUT_HOURS" "24"
  write_env_line "MAX_SESSIONS_PER_USER" "5"
  write_env_line "ENABLE_MCP" "false"
  write_env_line "MCP_CONFIG_PATH" ""
  write_env_line "ENABLE_GIT_INTEGRATION" "true"
  write_env_line "ENABLE_FILE_UPLOADS" "true"
  write_env_line "ENABLE_QUICK_ACTIONS" "true"
  write_env_line "MAX_FILE_UPLOAD_SIZE_MB" "100"
  write_env_line "MAX_ARCHIVE_PREVIEW_FILES" "5"
  write_env_line "ENABLE_SESSION_EXPORT" "true"
  write_env_line "ENABLE_IMAGE_UPLOADS" "true"
  write_env_line "ENABLE_CONVERSATION_MODE" "true"
  write_env_line "QUICK_ACTIONS_TIMEOUT" "120"
  write_env_line "GIT_OPERATIONS_TIMEOUT" "30"
  write_env_line "ENABLE_VOICE_MESSAGES" "false"
  write_env_line "LOG_LEVEL" "INFO"
  write_env_line "ENABLE_TELEMETRY" "false"
  write_env_line "SENTRY_DSN" ""
  write_env_line "ENVIRONMENT" "production"
  write_env_line "DEBUG" "false"
  write_env_line "DEVELOPMENT_MODE" "false"
} > "$INSTALL_DIR/.env"
chmod 600 "$INSTALL_DIR/.env" || error "Could not secure $INSTALL_DIR/.env"
ok

MANAGE_SCRIPT="$HOME/.claude-telegram-manage.sh"
cat > "$MANAGE_SCRIPT" <<EOF
#!/bin/bash
INSTALL_DIR="$INSTALL_DIR"
LOG_FILE="\$INSTALL_DIR/claude-telegram.log"
PID_FILE="\$INSTALL_DIR/claude-telegram.pid"

start() {
  if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
    echo "Claude Telegram already running (PID \$(cat "\$PID_FILE"))"
    exit 0
  fi
  cd "\$INSTALL_DIR" || exit 1
  nohup "\$INSTALL_DIR/.venv/bin/claude-telegram-bot" >> "\$LOG_FILE" 2>&1 &
  echo \$! > "\$PID_FILE"
  echo "Claude Telegram started (PID \$!)"
}

stop() {
  if [ -f "\$PID_FILE" ]; then
    kill "\$(cat "\$PID_FILE")" 2>/dev/null || true
    rm -f "\$PID_FILE"
  fi
  echo "Claude Telegram stopped"
}

case "\${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  logs) tail -f "\$LOG_FILE" ;;
  status)
    if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
      echo "Claude Telegram running (PID \$(cat "\$PID_FILE"))"
    else
      echo "Claude Telegram stopped"
    fi
    ;;
  *) echo "Usage: \$0 {status|logs|stop|start|restart}"; exit 1 ;;
esac
EOF
chmod +x "$MANAGE_SCRIPT"

step "Starting Claude Telegram"
if can_use_systemd; then
  SERVICE_USER="$(id -un)"
  SERVICE_HOME="$HOME"
  install_systemd_unit "claude-telegram.service" <<UNIT
[Unit]
Description=Claude Code Telegram Bot
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=HOME=$SERVICE_HOME
Environment=PATH=$(dirname "$(command -v claude)"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$INSTALL_DIR/.venv/bin/claude-telegram-bot
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  run_root_cmd systemctl daemon-reload || error "systemctl daemon-reload failed."
  run_root_cmd systemctl enable claude-telegram || error "Failed to enable claude-telegram."
  run_root_cmd systemctl restart claude-telegram || error "Failed to start claude-telegram. Run: journalctl -u claude-telegram -n 100"
  success "  Started via systemd."
else
  "$MANAGE_SCRIPT" restart
  success "  Started in background."
fi

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "  ${CYAN}Install${NC} : $INSTALL_DIR"
echo -e "  ${CYAN}Projects${NC}: $APPROVED_DIRECTORY"
if can_use_systemd; then
  echo -e "  ${CYAN}Status${NC}  : systemctl status claude-telegram"
  echo -e "  ${CYAN}Logs${NC}    : journalctl -u claude-telegram -f"
  echo -e "  ${CYAN}Stop${NC}    : systemctl stop claude-telegram"
else
  echo -e "  ${CYAN}Status${NC}  : ~/.claude-telegram-manage.sh status"
  echo -e "  ${CYAN}Logs${NC}    : ~/.claude-telegram-manage.sh logs"
  echo -e "  ${CYAN}Stop${NC}    : ~/.claude-telegram-manage.sh stop"
fi
echo -e "  ${CYAN}Auth${NC}    : claude auth login"
echo ""
