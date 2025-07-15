#!/bin/bash
set -e

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ===== Helpers =====
echo_color() { echo -e "${1}${2}${NC}"; }
step()       { echo_color "$YELLOW" "[Step $1] $2"; }
success()    { echo_color "$GREEN" "[OK] $1"; }
warn()       { echo_color "$YELLOW" "[WARN] $1"; }
error_exit() { echo_color "$RED" "[ERROR] $1"; exit 1; }

# ===== Parse Arguments =====
BACKUP_TAR=""

print_help() {
  cat <<EOF
Usage: $0 --backup <backup-tar.gz>

Options:
  --backup    Path to the nginx backup tarball
  --help      Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup) BACKUP_TAR="$2"; shift 2 ;;
    --help) print_help ;;
    *) error_exit "Unknown argument: $1" ;;
  esac
done

if [[ -z "$BACKUP_TAR" ]]; then
  error_exit "Backup file must be specified with --backup"
fi

if [[ ! -f "$BACKUP_TAR" ]]; then
  error_exit "Backup file not found: $BACKUP_TAR"
fi

# ===== Variables =====
RESTORE_DIR="/tmp/nginx-restore"

# ===== Step 1: Prepare restore workspace =====
step 1 "Preparing restore workspace..."
rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"
success "Workspace ready: $RESTORE_DIR"

# ===== Step 2: Extract backup archive =====
step 2 "Extracting backup archive..."
tar -xzf "$BACKUP_TAR" -C "$RESTORE_DIR"
success "Backup extracted"

# ===== Step 3: Check and create nginx user/group if missing =====
step 3 "Checking and creating nginx user/group if missing..."
if ! id nginx &>/dev/null; then
  useradd --system --no-create-home --shell /sbin/nologin nginx
  success "Created system user 'nginx'"
else
  success "User 'nginx' exists"
fi

if ! getent group nginx &>/dev/null; then
  groupadd --system nginx
  success "Created group 'nginx'"
else
  success "Group 'nginx' exists"
fi

# ===== Step 4: Restore nginx binary =====
step 4 "Restoring nginx binary..."
if [[ -f "$RESTORE_DIR/nginx" ]]; then
  cp "$RESTORE_DIR/nginx" /usr/sbin/nginx
  chmod +x /usr/sbin/nginx
  success "Nginx binary restored to /usr/sbin/nginx"
else
  warn "Nginx binary file not found in backup, skipping"
fi

# ===== Step 5: Restore nginx modules =====
step 5 "Restoring nginx modules..."
if [[ -d "$RESTORE_DIR/modules" ]]; then
  mkdir -p /usr/lib64/nginx/modules
  cp -r "$RESTORE_DIR/modules/"* /usr/lib64/nginx/modules/
  success "Modules restored to /usr/lib64/nginx/modules"
else
  warn "Modules directory missing in backup, skipping"
fi

# ===== Step 6: Restore nginx configuration =====
step 6 "Restoring nginx configuration..."
if [[ -d "$RESTORE_DIR/nginx-conf" ]]; then
  mkdir -p /etc/nginx
  cp -r "$RESTORE_DIR/nginx-conf/"* /etc/nginx/
  success "Nginx config restored to /etc/nginx"
else
  warn "Nginx config directory missing in backup, skipping"
fi

# ===== Step 7: Create cache and log directories if missing =====
step 7 "Creating necessary cache and log directories..."
for d in /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp /var/cache/nginx/fastcgi_temp \
  /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp /var/log/nginx /var/run; do
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d"
    chown -R nginx:nginx "$d"
    success "Created directory $d"
  else
    success "Directory $d exists"
  fi
done

# ===== Step 8: Restore systemd service file(s) =====
step 8 "Restoring systemd service file(s)..."
SYSTEMD_TARGET="/etc/systemd/system/nginx.service"

if [[ -f "$RESTORE_DIR/nginx.service" ]]; then
  cp "$RESTORE_DIR/nginx.service" "$SYSTEMD_TARGET"
  success "Systemd service restored from $RESTORE_DIR/nginx.service"
elif [[ -f "$RESTORE_DIR/systemd/nginx.service" ]]; then
  cp "$RESTORE_DIR/systemd/nginx.service" "$SYSTEMD_TARGET"
  success "Systemd service restored from $RESTORE_DIR/systemd/nginx.service"
else
  warn "Systemd service file missing in backup, skipping"
fi

# ===== Step 9: Reload systemd daemon and enable nginx service =====
step 9 "Reloading systemd daemon and enabling nginx service..."
systemctl daemon-reload
if systemctl enable nginx; then
  success "Enabled nginx service"
else
  warn "Failed to enable nginx service"
fi

if systemctl restart nginx; then
  success "Nginx service started"
else
  warn "Failed to start nginx service, please check logs"
fi

# ===== Finished =====
echo
echo_color "$GREEN" "Nginx restoration completed successfully."

exit 0
