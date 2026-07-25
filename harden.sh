#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

log()  { echo -e "${GREEN}[+]${RESET} $*"; }
info() { echo -e "${CYAN}[*]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*" >&2; }
die()  { echo -e "${RED}[x]${RESET} $*" >&2; exit 1; }

require_root() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "Run this script as root."
}

detect_os() {
  [ -r /etc/os-release ] || die "Cannot detect OS."
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) die "Unsupported OS: ${ID:-unknown}. Supported: Ubuntu/Debian" ;;
  esac
}

backup_file() {
  local f="$1"
  [ -f "$f" ] && cp -a "$f" "${f}.bak.$(date +%F-%H%M%S)"
}

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local value
  read -r -p "$prompt_text [$default_value]: " value
  value="${value:-$default_value}"
  printf -v "$var_name" "%s" "$value"
}

prompt_yes_no() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local value

  while true; do
    read -r -p "$prompt_text [$default_value]: " value
    value="${value:-$default_value}"
    case "$value" in
      y|Y|yes|YES|Yes)
        printf -v "$var_name" "yes"
        return
        ;;
      n|N|no|NO|No)
        printf -v "$var_name" "no"
        return
        ;;
      *)
        warn "Please answer yes or no."
        ;;
    esac
  done
}

prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local value

  while true; do
    read -r -p "$prompt_text: " value
    [ -n "$value" ] || { warn "This field is required."; continue; }
    printf -v "$var_name" "%s" "$value"
    return
  done
}

validate_port() {
  local p="$1"
  case "$p" in
    ""|*[!0-9]*) return 1 ;;
    *)
      [ "$p" -ge 1 ] && [ "$p" -le 65535 ]
      ;;
  esac
}

normalize_ports() {
  OPEN_TCP_PORTS=()
  OPEN_UDP_PORTS=()

  if [ -n "${OPEN_TCP_PORTS_RAW:-}" ]; then
    IFS=, read -r -a _tcp_parts <<< "$OPEN_TCP_PORTS_RAW"
    for p in "${_tcp_parts[@]}"; do
      p="$(echo "$p" | tr -d "[:space:]")"
      [ -n "$p" ] || continue
      validate_port "$p" || die "Invalid TCP port: $p"
      OPEN_TCP_PORTS+=("$p")
    done
  fi

  if [ -n "${OPEN_UDP_PORTS_RAW:-}" ]; then
    IFS=, read -r -a _udp_parts <<< "$OPEN_UDP_PORTS_RAW"
    for p in "${_udp_parts[@]}"; do
      p="$(echo "$p" | tr -d "[:space:]")"
      [ -n "$p" ] || continue
      validate_port "$p" || die "Invalid UDP port: $p"
      OPEN_UDP_PORTS+=("$p")
    done
  fi
}

collect_inputs() {
  echo
  echo -e "${BLUE}========================================${RESET}"
  echo -e "${BLUE}         VPS Hardening Wizard          ${RESET}"
  echo -e "${BLUE}========================================${RESET}"
  echo

  prompt_default ADMIN_USER "Admin username" "myadmin"

  while true; do
    prompt_default SSH_PORT "SSH port" "2222"
    validate_port "$SSH_PORT" && break
    warn "Invalid SSH port."
  done

  prompt_default TIMEZONE "Timezone" "Asia/Tehran"

  echo
  echo -e "${CYAN}SSH public key example:${RESET}"
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@laptop"
  prompt_required ADMIN_PUBKEY "Paste your SSH public key"

  echo
  prompt_default OPEN_TCP_PORTS_RAW "Extra TCP ports to open (comma-separated)" "80,443"
  prompt_default OPEN_UDP_PORTS_RAW "Extra UDP ports to open (comma-separated)" ""

  prompt_yes_no INSTALL_FAIL2BAN "Install and configure fail2ban?" "yes"
  prompt_yes_no ENABLE_AUTO_UPDATES "Enable unattended security updates?" "yes"
  prompt_yes_no APPLY_SYSCTL "Apply sysctl hardening?" "yes"
  prompt_yes_no DISABLE_ROOT_LOGIN "Disable root SSH login?" "yes"
  prompt_yes_no DISABLE_PASSWORD_LOGIN "Disable SSH password login?" "yes"
  prompt_yes_no OPEN_3XUI_PORT "Open 3x-ui panel port?" "no"

  if [ "$OPEN_3XUI_PORT" = "yes" ]; then
    while true; do
      prompt_default PANEL_PORT "3x-ui panel TCP port" "2053"
      validate_port "$PANEL_PORT" && break
      warn "Invalid panel port."
    done

    if [ -n "$OPEN_TCP_PORTS_RAW" ]; then
      OPEN_TCP_PORTS_RAW="${OPEN_TCP_PORTS_RAW},${PANEL_PORT}"
    else
      OPEN_TCP_PORTS_RAW="${PANEL_PORT}"
    fi
  fi

  echo
  echo -e "${BLUE}--------------- Review ----------------${RESET}"
  echo "Admin user:              $ADMIN_USER"
  echo "SSH port:                $SSH_PORT"
  echo "Timezone:                $TIMEZONE"
  echo "Open TCP ports:          ${OPEN_TCP_PORTS_RAW:-none}"
  echo "Open UDP ports:          ${OPEN_UDP_PORTS_RAW:-none}"
  echo "Disable root SSH login:  $DISABLE_ROOT_LOGIN"
  echo "Disable password login:  $DISABLE_PASSWORD_LOGIN"
  echo "Install fail2ban:        $INSTALL_FAIL2BAN"
  echo "Enable auto updates:     $ENABLE_AUTO_UPDATES"
  echo "Apply sysctl hardening:  $APPLY_SYSCTL"
  echo -e "${BLUE}---------------------------------------${RESET}"
  echo
  echo -e "${YELLOW}Warning:${RESET} If your SSH key is wrong and password login is disabled,"
  echo "you may lose access after SSH reload."
  echo

  local confirm
  read -r -p "Apply these changes? [yes/no]: " confirm
  case "$confirm" in
    yes|y|Y|YES) ;;
    *) die "Cancelled by user." ;;
  esac
}

install_packages() {
  log "Updating system and installing required packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get -y upgrade
  apt-get install -y sudo ufw ca-certificates curl openssh-server rsyslog
}

install_optional_packages() {
  local pkgs=()

  [ "$INSTALL_FAIL2BAN" = "yes" ] && pkgs+=(fail2ban)
  [ "$ENABLE_AUTO_UPDATES" = "yes" ] && pkgs+=(unattended-upgrades apt-listchanges)

  if [ "${#pkgs[@]}" -gt 0 ]; then
    log "Installing optional packages: ${pkgs[*]}"
    apt-get install -y "${pkgs[@]}"
  fi
}

ensure_admin_user() {
  if id "$ADMIN_USER" >/dev/null 2>&1; then
    log "User $ADMIN_USER already exists"
  else
    log "Creating admin user: $ADMIN_USER"
    adduser --disabled-password --gecos "" "$ADMIN_USER"
  fi

  usermod -aG sudo "$ADMIN_USER"

  local home_dir
  home_dir="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
  [ -n "$home_dir" ] || die "Could not determine home directory for $ADMIN_USER"

  log "Installing SSH key for $ADMIN_USER"
  install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$home_dir/.ssh"
  touch "$home_dir/.ssh/authorized_keys"
  chmod 600 "$home_dir/.ssh/authorized_keys"
  chown "$ADMIN_USER:$ADMIN_USER" "$home_dir/.ssh/authorized_keys"

  if ! grep -Fq "$ADMIN_PUBKEY" "$home_dir/.ssh/authorized_keys"; then
    printf "%s\n" "$ADMIN_PUBKEY" >> "$home_dir/.ssh/authorized_keys"
    log "SSH key added"
  else
    info "SSH key already exists"
  fi

  chown -R "$ADMIN_USER:$ADMIN_USER" "$home_dir/.ssh"
}

configure_sshd() {
  local sshd_cfg="/etc/ssh/sshd_config"
  local permit_root="prohibit-password"
  local password_auth="yes"

  [ "$DISABLE_ROOT_LOGIN" = "yes" ] && permit_root="no"
  [ "$DISABLE_PASSWORD_LOGIN" = "yes" ] && password_auth="no"

  backup_file "$sshd_cfg"

  log "Configuring SSH"
  cat > "$sshd_cfg" <<EOF
Port $SSH_PORT
Protocol 2
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

PermitRootLogin $permit_root
PasswordAuthentication $password_auth
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PubkeyAuthentication yes

X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive no
PermitUserEnvironment no
Compression no
PrintMotd no
UseDNS no

AllowUsers $ADMIN_USER
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

  if [ "$DISABLE_PASSWORD_LOGIN" = "yes" ]; then
    echo "AuthenticationMethods publickey" >> "$sshd_cfg"
  fi

  sshd -t
  systemctl enable ssh >/dev/null 2>&1 || true
  systemctl restart ssh 2>/dev/null || systemctl restart sshd
}

configure_ufw() {
  log "Configuring UFW firewall"
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp"

  for p in "${OPEN_TCP_PORTS[@]}"; do
    ufw allow "${p}/tcp"
  done

  for p in "${OPEN_UDP_PORTS[@]}"; do
    ufw allow "${p}/udp"
  done

  ufw --force enable
}

configure_fail2ban() {
  [ "$INSTALL_FAIL2BAN" = "yes" ] || return 0

  log "Configuring fail2ban"
  mkdir -p /etc/fail2ban
  cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd
banaction = ufw

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban
}

configure_auto_updates() {
  [ "$ENABLE_AUTO_UPDATES" = "yes" ] || return 0

  log "Configuring unattended upgrades"
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

  cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
  "\${distro_id}:\${distro_codename}";
  "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

  systemctl enable unattended-upgrades || true
  systemctl restart unattended-upgrades || true
}

configure_sysctl() {
  [ "$APPLY_SYSCTL" = "yes" ] || return 0

  log "Applying sysctl hardening"
  cat > /etc/sysctl.d/99-vps-hardening.conf <<EOF
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0

net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF

  sysctl --system >/dev/null
}

configure_time() {
  log "Configuring timezone and NTP"
  timedatectl set-timezone "$TIMEZONE" || true
  timedatectl set-ntp true || true
}

disable_unneeded_services() {
  log "Disabling common unused services if present"
  for svc in avahi-daemon cups bluetooth; do
    if systemctl list-unit-files | awk "{print \$1}" | grep -qx "${svc}.service"; then
      systemctl disable --now "$svc" || true
    fi
  done
}

post_checks() {
  echo
  echo -e "${BLUE}============= Post Checks =============${RESET}"
  ss -tulpn || true
  echo
  ufw status verbose || true
  echo
  if [ "$INSTALL_FAIL2BAN" = "yes" ]; then
    fail2ban-client status sshd || true
    echo
  fi
}

main() {
  require_root
  detect_os
  collect_inputs
  normalize_ports
  install_packages
  install_optional_packages
  ensure_admin_user
  configure_sshd
  configure_ufw
  configure_fail2ban
  configure_auto_updates
  configure_sysctl
  configure_time
  disable_unneeded_services
  post_checks

  echo
  echo -e "${GREEN}Hardening complete.${RESET}"
  echo -e "${YELLOW}Test this before closing current session:${RESET}"
  echo "ssh -p $SSH_PORT $ADMIN_USER@YOUR_SERVER_IP"
}

main
