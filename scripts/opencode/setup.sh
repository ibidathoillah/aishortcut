#!/bin/bash

# ============================================
# OpenCode + Telegram Bot Auto-Installer (Enhanced)
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
OS="$(uname -s)"
ARCH="$(uname -m)"

is_root() { [ "$EUID" -eq 0 ]; }

trap 'echo -e "\n  ${RED}Setup interrupted.${NC}"; exit 1' INT TERM

echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  OpenCode + Telegram Bot Auto-Installer    ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

# --- Process Monitoring & Interactive Menu ---
list_active_instances() {
  echo -e "${BOLD}Current Active Instances (grouped by Port):${NC}"
  
  # Get unique ports from running opencode processes
  local active_ports
  active_ports=$(ps -ef | grep "opencode serve" | grep -v grep | grep -o "\-\-port [0-9]*" | awk '{print $2}' | sort -u)
  
  if [[ -z "$active_ports" ]]; then
    echo -e "  ${YELLOW}No active instances found.${NC}"
    echo ""
    return 1
  fi

  for port in $active_ports; do
    # Find PIDs for this port
    local pids
    pids=$(ps -ef | grep "opencode serve" | grep -v grep | grep "\-\-port $port" | awk '{print $2}' | tr '\n' ' ')
    
    # Try to find the token from .env files
    local token="Unknown"
    local token_masked="Not found"
    local env_file
    env_file=$(find "$HOME" -name ".env" -maxdepth 3 2>/dev/null | xargs grep -l "OPENCODE_API_URL=http://127.0.0.1:$port" 2>/dev/null | head -1)
    
    if [[ -f "$env_file" ]]; then
      token=$(grep "TELEGRAM_BOT_TOKEN=" "$env_file" | cut -d= -f2)
      token_masked="${token:0:4}...${token: -4}"
    fi

    # Check if a monitor script is also running for this port
    local monitor_pid
    monitor_pid=$(ps -ef | grep "keep-alive-server.sh" | grep -v grep | grep -v "ps -ef" | while read -r mline; do
      mpid=$(echo "$mline" | awk '{print $2}')
      # Verify if this monitor belongs to this port's directory
      mcmd=$(echo "$mline" | awk '{$1=$2=$3=$4=$5=$6=$7=""; print $0}')
      if [[ "$mcmd" == *"-telegram-bot-$port"* ]]; then
        echo "$mpid"
      fi
    done | head -1)

    echo -ne "  ${BLUE}Port: $port${NC} | PIDs: $pids"
    [[ -n "$monitor_pid" ]] && echo -ne " (Monitor: $monitor_pid)"
    echo -e " | Bot: $token_masked"
  done
  echo ""
  return 0
}

if ps -ef | grep "opencode serve" | grep -v grep >/dev/null; then
  list_active_instances
  echo -e "${BOLD}What would you like to do?${NC}"
  echo -e "  [A] Add new instance"
  echo -e "  [R] Replace/Restart existing (kill all on port)"
  echo -e "  [S] Stop an instance"
  echo -e "  [Q] Quit"
  echo -ne "${CYAN}  Select an option: ${NC}"
  read -r choice
  case $choice in
    [Rr]* ) 
      echo -ne "${CYAN}  Enter port to replace: ${NC}"
      read -r target_port
      echo -e "${YELLOW}  Cleaning up processes on port $target_port...${NC}"
      # Kill the monitor scripts first to prevent auto-restart
      ps -ef | grep "keep-alive" | grep "$target_port" | awk '{print $2}' | xargs kill -9 2>/dev/null
      # Kill the actual processes
      pkill -9 -f "opencode serve --port $target_port"
      pkill -9 -f "bun run start" # This might be aggressive if multiple bots exist
      # More specific cleanup for the bot on this port
      ps -ef | grep "bun run start" | grep "$target_port" | awk '{print $2}' | xargs kill -9 2>/dev/null
      PORT=$target_port
      ;;
    [Ss]* )
      echo -ne "${CYAN}  Enter port to stop: ${NC}"
      read -r target_port
      echo -e "${YELLOW}  Stopping all processes for port $target_port...${NC}"
      ps -ef | grep "keep-alive" | grep "$target_port" | awk '{print $2}' | xargs kill -9 2>/dev/null
      pkill -9 -f "opencode serve --port $target_port"
      ps -ef | grep "bun run start" | grep "$target_port" | awk '{print $2}' | xargs kill -9 2>/dev/null
      echo -e "${GREEN}  Stopped.${NC}"
      exit 0
      ;;
    [Qq]* ) exit 0 ;;
    * ) [ -z "$PORT" ] && PORT=$((RANDOM % 64511 + 1024)) ;;
  esac
else
  [ -z "$PORT" ] && PORT=$((RANDOM % 64511 + 1024))
fi

if [ -z "$BOT_TOKEN" ]; then
  # Check if we can find a token in existing .env based on PORT
  if [ -n "$PORT" ]; then
    POTENTIAL_ENV=$(find "$HOME" -name ".env" -maxdepth 3 2>/dev/null | xargs grep -l "OPENCODE_API_URL=http://127.0.0.1:$PORT" 2>/dev/null | head -1)
    if [ -f "$POTENTIAL_ENV" ]; then
       EXISTING_TOKEN=$(grep "TELEGRAM_BOT_TOKEN=" "$POTENTIAL_ENV" | cut -d= -f2)
    fi
  fi
  
  if [ -z "$EXISTING_TOKEN" ]; then
     # Fallback to any token
     EXISTING_TOKEN=$(find "$HOME" -name ".env" -maxdepth 3 2>/dev/null | xargs grep "TELEGRAM_BOT_TOKEN=" 2>/dev/null | head -1 | cut -d= -f2)
  fi

  if [ -n "$EXISTING_TOKEN" ]; then
    warn "Found existing token: ${EXISTING_TOKEN:0:4}...${EXISTING_TOKEN: -4}"
    echo -ne "${CYAN}  Press Enter to reuse, or type new Token: ${NC}"
    read -r input_token
    BOT_TOKEN="${input_token:-$EXISTING_TOKEN}"
  else
    warn "No Telegram Bot Token provided."
    echo -ne "${CYAN}  Enter your Telegram Bot Token: ${NC}"
    read -r BOT_TOKEN
  fi
  [ -z "$BOT_TOKEN" ] && error "Bot Token is required."
fi

# --- Install Prerequisites ---
step "Checking prerequisites ($OS)"
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

# --- Install OpenCode ---
step "Installing OpenCode"
if command -v opencode >/dev/null 2>&1; then
  success "  Already installed: $(opencode --version)"
else
  substep "Detecting latest version..."
  VERSION=$(curl -sfL https://api.github.com/repos/anomalyco/opencode/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
  [ -z "$VERSION" ] && error "Could not fetch latest OpenCode version."

  case "$OS" in
    Linux)
      raw_arch=$ARCH
      case "$raw_arch" in
        x86_64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) error "Unsupported Linux architecture: $raw_arch" ;;
      esac
      needs_baseline=false
      if [ "$arch" = "x64" ] && ! grep -qi avx2 /proc/cpuinfo 2>/dev/null; then
        needs_baseline=true
      fi
      target="$arch"
      if [ "$needs_baseline" = "true" ]; then target="$target-baseline"; fi
      filename="opencode-linux-$target.tar.gz"
      EXTRACT_CMD="tar -xzf"
      ;;
    Darwin)
      case "$ARCH" in
        x86_64) arch="x64" ;;
        arm64) arch="arm64" ;;
        *) error "Unsupported macOS architecture: $ARCH" ;;
      esac
      # Note: We use the zip assets for macOS
      filename="opencode-darwin-$arch.zip"
      EXTRACT_CMD="unzip -o"
      ;;
    *) error "Unsupported OS: $OS" ;;
  esac

  url="https://github.com/anomalyco/opencode/releases/download/v$VERSION/$filename"
  tmpdir=$(mktemp -d)

  substep "Downloading v$VERSION ($filename) ..."
  curl -fSL -o "$tmpdir/$filename" "$url" || error "Download failed for $filename"

  substep "Extracting..."
  $EXTRACT_CMD "$tmpdir/$filename" -C "$tmpdir" || error "Extraction failed."
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
  # Add to shell profile for future use
  if [ "$OS" = "Darwin" ]; then
    PROFILE="$HOME/.zshrc"
  else
    PROFILE="$HOME/.bashrc"
  fi
  if ! grep -q ".bun/bin" "$PROFILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$PROFILE"
  fi
  command -v bun >/dev/null 2>&1 || error "Bun installation failed."
  success "  Installed: $(bun --version)"
fi

# --- Setup Telegram Bot Repo ---
if is_root; then
  INSTALL_DIR="/opt/opencode-telegram-bot-$PORT"
else
  INSTALL_DIR="$HOME/opencode-telegram-bot-$PORT"
fi

step "Setting up Telegram bot repository ($PORT)"
if [ -d "$INSTALL_DIR" ]; then
  substep "Directory exists at $INSTALL_DIR"
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

# --- macOS Sleep Prevention ---
if [ "$OS" = "Darwin" ]; then
  step "macOS Sleep Prevention"
  info "  To keep the bot running even when the lid is closed,"
  info "  use the 'caffeinate' command. This script will try to"
  info "  activate it in the background."
  # Check if already running to avoid duplication
  if ! pgrep caffeinate >/dev/null; then
    nohup caffeinate -dis >/dev/null 2>&1 &
    substep "Caffeinate activated (PID $!)"
  else
    substep "Caffeinate already running."
  fi
fi

# --- Start OpenCode & Bot (Auto-Reconnect) ---
create_keep_alive_script() {
  local name=$1
  local cmd=$2
  local log_file=$3
  cat > "$INSTALL_DIR/keep-alive-$name.sh" <<EOF
#!/bin/bash
while true; do
  echo "[$(date)] Starting $name..." >> "$log_file"
  $cmd >> "$log_file" 2>&1
  echo "[$(date)] $name crashed or stopped. Restarting in 5s..." >> "$log_file"
  sleep 5
done
EOF
  chmod +x "$INSTALL_DIR/keep-alive-$name.sh"
}

step "Starting Services"
if is_root && [ "$OS" = "Linux" ]; then
  # Systemd logic
  cat > /etc/systemd/system/opencode-server-$PORT.service <<UNIT
[Unit]
Description=OpenCode Server ($PORT)
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

  cat > /etc/systemd/system/opencode-telegram-$PORT.service <<UNIT
[Unit]
Description=OpenCode Telegram Bot ($PORT)
After=network.target opencode-server-$PORT.service
Wants=opencode-server-$PORT.service

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
  systemctl enable opencode-server-$PORT opencode-telegram-$PORT
  systemctl restart opencode-server-$PORT opencode-telegram-$PORT
  success "  Started via systemd (port $PORT)."
else
  # Background loop logic for Mac and non-root Linux
  substep "Creating auto-reconnect scripts..."
  create_keep_alive_script "server" "$HOME/.opencode/bin/opencode serve --port $PORT" "$INSTALL_DIR/opencode-server.log"
  create_keep_alive_script "bot" "cd $INSTALL_DIR && bun run start" "$INSTALL_DIR/telegram-bot.log"
  
  # Ensure no old monitors are running for this port
  ps -ef | grep "keep-alive" | grep "$PORT" | awk '{print $2}' | xargs kill -9 2>/dev/null
  
  nohup "$INSTALL_DIR/keep-alive-server.sh" >/dev/null 2>&1 &
  server_pid=$!
  nohup "$INSTALL_DIR/keep-alive-bot.sh" >/dev/null 2>&1 &
  bot_pid=$!
  
  success "  Started in background with auto-reconnect (port $PORT)."
  substep "Server Monitor PID: $server_pid"
  substep "Bot Monitor PID: $bot_pid"
fi

# --- Done ---
echo -e "\n${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}              SETUP COMPLETE!               ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "  ${CYAN}OpenCode${NC} : http://127.0.0.1:$PORT"
if is_root && [ "$OS" = "Linux" ]; then
  echo -e "  ${CYAN}Status${NC}   : systemctl status opencode-telegram-$PORT"
else
  echo -e "  ${CYAN}Logs${NC}     : tail -f $INSTALL_DIR/telegram-bot.log"
fi
echo -e "  ${YELLOW}Tip${NC}      : If on Mac, keep this terminal open or ensure 'caffeinate' is running."
echo ""
