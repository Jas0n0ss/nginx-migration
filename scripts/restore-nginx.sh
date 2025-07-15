#!/bin/bash
# Restore Nginx backup archive

set -euo pipefail

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# ===== Defaults =====
BACKUP_ARCHIVE=""
WORK_DIR="/tmp/nginx-restore"
NGINX_BIN="/usr/sbin/nginx"
MODULES_DIR="/usr/lib64/nginx/modules"
NGINX_CONF_DIR="/etc/nginx"
SYSTEMD_PATHS=("/usr/lib/systemd/system/nginx.service" "/etc/systemd/system/nginx.service")

# ===== Helpers =====
echo_color() { echo -e "${1}${2}${NC}"; }
step()       { echo_color "$YELLOW" "[Step $1] $2"; }
success()    { echo_color "$GREEN" "[OK] $1"; }
warning()    { echo_color "$YELLOW" "[WARN] $1"; }
error_exit() { echo_color "$RED" "[ERROR] $1"; exit 1; }

print_help() {
  cat <<EOF
Usage: $0 --backup <backup-archive.tar.gz>

Options:
  --backup <file>    Backup archive to restore
  --help             Show this help message

EOF
  exit 0
}

# ===== Parse Args =====
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)
      BACKUP_ARCHIVE="$2"
      shift 2
      ;;
    --help)
      print_help
      ;;
    *)
      echo_color "$RED" "Unknown argument: $1"
      print_help
      ;;
  esac
done

if [[ -z "$BACKUP_ARCHIVE" ]]; then
  error_exit "Backup archive is required. Use --backup <file>"
fi

if [[ ! -f "$BACKUP_ARCHIVE" ]]; then
  error_exit "Backup archive not found: $BACKUP_ARCHIVE"
fi

# ===== Step 1: Prepare workspace =====
step 1 "Preparing restore workspace..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
success "Workspace ready: $WORK_DIR"

# ===== Step 2: Extract backup =====
step 2 "Extracting backup archive..."
tar -xzf "$BACKUP_ARCHIVE" -C /tmp
success "Backup extracted"

# ===== Step 3: Restore nginx binary =====
step 3 "Restoring nginx binary..."
cp -v "$WORK_DIR/nginx" "$NGINX_BIN"
chmod 755 "$NGINX_BIN"
chown root:root "$NGINX_BIN"
success "Nginx binary restored"

# ===== Step 4: Restore modules =====
step 4 "Restoring nginx modules..."
if [[ -d "$WORK_DIR/modules" ]]; then
  mkdir -p "$MODULES_DIR"
  cp -rv "$WORK_DIR/modules/"* "$MODULES_DIR/"
  chown -R nginx:nginx "$MODULES_DIR"
  chmod -R 755 "$MODULES_DIR"
  success "Modules restored"
else
  warning "Modules directory missing in backup"
fi

# ===== Step 5: Restore nginx config =====
step 5 "Restoring nginx configuration..."
if [[ -d "$WORK_DIR/nginx-conf" ]]; then
  mkdir -p "$NGINX_CONF_DIR"
  cp -rv "$WORK_DIR/nginx-conf/"* "$NGINX_CONF_DIR/"
  chown -R nginx:nginx "$NGINX_CONF_DIR"
  chmod -R 644 "$NGINX_CONF_DIR"
  success "Configuration restored"
else
  warning "Nginx config directory missing in backup"
fi

# ===== Step 6: Restore systemd unit =====
step 6 "Restoring systemd service file..."
if [[ -f "$WORK_DIR/nginx.service" ]]; then
  # Try to restore to the first valid systemd path found
  for svc in "${SYSTEMD_PATHS[@]}"; do
    if [[ -d $(dirname "$svc") ]]; then
      cp -v "$WORK_DIR/nginx.service" "$svc"
      success "Systemd unit restored to $svc"
      break
    fi
  done
else
  warning "Systemd service file missing in backup"
fi

# ===== Step 7: Reload systemd and restart nginx =====
step 7 "Reloading systemd daemon and restarting nginx..."
systemctl daemon-reload
systemctl restart nginx
success "Nginx service restarted"

# ===== Cleanup =====
step 8 "Cleaning up temporary files..."
rm -rf "$WORK_DIR"
success "Cleanup done"

echo_color "$MAGENTA" "[DONE] Nginx restore completed successfully"
