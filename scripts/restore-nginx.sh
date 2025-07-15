#!/bin/bash
set -e

# ===== Colors for output =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# ===== Helpers =====
echo_color() { echo -e "${1}${2}${NC}"; }
step()       { echo_color "$YELLOW" "[Step $1] $2"; }
success()    { echo_color "$GREEN" "[OK] $1"; }
warning()    { echo_color "$YELLOW" "[WARN] $1"; }
error_exit() { echo_color "$RED" "[ERROR] $1"; exit 1; }

print_help() {
  cat <<EOF
Usage: $0 --backup <backup-tar.gz>

Options:
  --backup <file>     Specify backup tarball file to restore from
  --help              Show this help message
EOF
  exit 0
}

# ===== Parse arguments =====
BACKUP_TAR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup) BACKUP_TAR="$2"; shift 2 ;;
    --help) print_help ;;
    *) echo_color "$RED" "Unknown argument: $1"; print_help ;;
  esac
done

[[ -z "$BACKUP_TAR" ]] && error_exit "Backup tarball is required. Use --backup <file>"

[[ ! -f "$BACKUP_TAR" ]] && error_exit "Backup file '$BACKUP_TAR' not found."

# ===== Step 1: Prepare restore workspace =====
RESTORE_DIR="/tmp/nginx-backup"


step 1 "Preparing restore workspace..."
[[ -d "$RESTORE_DIR" ]] && rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"
success "Workspace ready: $RESTORE_DIR"

# ===== Step 2: Extract backup archive =====
step 2 "Extracting backup archive..."
tar -xf "$BACKUP_TAR" -C /tmp
success "Backup extracted"

# ===== Step 3: Check and create nginx user/group if missing =====
step 3 "Checking and creating nginx user/group if missing..."
if id -u nginx &>/dev/null; then
  success "User 'nginx' exists"
else
  useradd --system --no-create-home --shell /sbin/nologin nginx
  success "Created system user 'nginx'"
fi

if getent group nginx &>/dev/null; then
  success "Group 'nginx' exists"
else
  groupadd --system nginx
  success "Created system group 'nginx'"
fi

# ===== Step 4: Restore nginx binary =====
step 4 "Restoring nginx binary..."
if [[ -f "$RESTORE_DIR/nginx" ]]; then
  cp "$RESTORE_DIR/nginx" /usr/sbin/nginx
  chmod 755 /usr/sbin/nginx
  chown root:root /usr/sbin/nginx
  success "Nginx binary restored"
else
  warning "Nginx binary file not found in backup, skipping"
fi

# ===== Step 5: Restore nginx modules =====
step 5 "Restoring nginx modules..."
if [[ -d "$RESTORE_DIR/modules" ]]; then
  mkdir -p /usr/lib64/nginx/modules
  cp -r "$RESTORE_DIR/modules/"* /usr/lib64/nginx/modules/
  chown -R root:root /usr/lib64/nginx/modules
  success "Modules restored"
else
  warning "Modules directory missing in backup, skipping"
fi

# ===== Step 6: Restore nginx configuration =====
step 6 "Restoring nginx configuration..."
if [[ -d "$RESTORE_DIR/nginx-conf" ]]; then
  mkdir -p /etc/nginx
  cp -r "$RESTORE_DIR/nginx-conf/"* /etc/nginx/
  chown -R root:root /etc/nginx
  success "Configuration restored"
else
  warning "Nginx config directory missing in backup, skipping"
fi

# ===== Step 7: Create necessary cache and log directories =====
step 7 "Creating necessary cache and log directories..."
declare -a DIRS=(
  "/var/cache/nginx/client_temp"
  "/var/cache/nginx/proxy_temp"
  "/var/cache/nginx/fastcgi_temp"
  "/var/cache/nginx/uwsgi_temp"
  "/var/cache/nginx/scgi_temp"
  "/var/log/nginx"
  "/var/run"
)

for dir in "${DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    chown -R nginx:nginx "$dir"
    success "Created directory $dir"
  else
    success "Directory $dir exists"
  fi
done

# ===== Step 8: Restore systemd service file =====
step 8 "Restoring systemd service file(s)..."

SYSTEMD_DST="/etc/systemd/system/nginx.service"
if [[ -f "$RESTORE_DIR/systemd/nginx.service" ]]; then
  cp "$RESTORE_DIR/systemd/nginx.service" "$SYSTEMD_DST"
  chmod 644 "$SYSTEMD_DST"
  chown root:root "$SYSTEMD_DST"
  success "Systemd service restored to $SYSTEMD_DST"
else
  warning "Systemd service file missing in backup, skipping"
fi

# ===== Step 9: Reload systemd and enable nginx service =====
step 9 "Reloading systemd daemon and enabling nginx service..."
systemctl daemon-reload || warning "Failed to reload systemd daemon"
if systemctl enable nginx; then
  success "Nginx service enabled"
else
  warning "Failed to enable nginx service"
fi

if systemctl restart nginx; then
  success "Nginx service restarted"
else
  warning "Failed to start nginx service, please check logs"
fi

echo_color "$MAGENTA" "\nNginx restoration completed successfully.\n"
