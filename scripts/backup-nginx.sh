#!/bin/bash
# Backup Nginx binary, modules, config, systemd service, and dependencies

set -euo pipefail

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# ===== Defaults =====
EXCLUDES=()
NGINX_BIN="/usr/sbin/nginx"
MODULES_DIR="/usr/lib64/nginx/modules"
NGINX_CONF_DIR="/etc/nginx"
SYSTEMD_PATHS=("/usr/lib/systemd/system/nginx.service" "/etc/systemd/system/nginx.service")
WORK_DIR="/tmp/nginx-backup"
DATE_STR=$(date +%Y%m%d)
HOSTNAME=$(hostname -s)
NGINX_VERSION=$($NGINX_BIN -v 2>&1 | grep -o '[0-9.]\+' | head -1)
BACKUP_NAME="nginx-backup-${HOSTNAME}-nginx${NGINX_VERSION}-${DATE_STR}.tar.gz"
BACKUP_TAR="/tmp/${BACKUP_NAME}"

# ===== Helpers =====
echo_color() { echo -e "${1}${2}${NC}"; }
step()       { echo_color "$YELLOW" "[Step $1] $2"; }
success()    { echo_color "$GREEN" "[OK] $1"; }
warning()    { echo_color "$YELLOW" "[WARN] $1"; }
error_exit() { echo_color "$RED" "[ERROR] $1"; exit 1; }

print_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  --output <file>     Specify output tar.gz file (default: $BACKUP_TAR)
  --exclude <path>    Exclude a directory from backup (can be used multiple times)
  --help              Show this help message

Examples:
  $0                                 # Default backup
  $0 --output /tmp/mybackup.tar.gz   # Custom output
  $0 --exclude /data/static          # Exclude a directory

EOF
  exit 0
}

# ===== Parse Arguments =====
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) BACKUP_TAR="$2"; shift 2 ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
    --help) print_help ;;
    *) echo_color "$RED" "Unknown argument: $1"; print_help ;;
  esac
done

# ===== Step 1: Prepare workspace =====
step 1 "Preparing backup workspace..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
success "Workspace ready: $WORK_DIR"

# ===== Step 2: Backup nginx binary =====
step 2 "Backing up nginx binary..."
cp -v "$NGINX_BIN" "$WORK_DIR/"
success "Nginx binary backed up"

# ===== Step 3: Backup nginx modules =====
step 3 "Backing up nginx modules..."
mkdir -p "$WORK_DIR/modules"
if [[ -d "$MODULES_DIR" ]]; then
  cp -rv "$MODULES_DIR/"* "$WORK_DIR/modules/"
  success "Modules backed up"
else
  warning "Modules directory not found: $MODULES_DIR"
fi

# ===== Step 4: Backup nginx config =====
step 4 "Backing up nginx configuration..."
mkdir -p "$WORK_DIR/nginx-conf"
if [[ -d "$NGINX_CONF_DIR" ]]; then
  cp -rv "$NGINX_CONF_DIR/"* "$WORK_DIR/nginx-conf/"
  success "Configuration backed up"
else
  warning "Nginx config directory not found: $NGINX_CONF_DIR"
fi

# ====== Step 5. Backup nginx systemd service ======
step 5 "Backing up nginx systemd service..."

mkdir -p "$WORK_DIR/systemd"

SYSTEMD_PATHS=(
  "/etc/systemd/system/nginx.service"
  "/usr/lib/systemd/system/nginx.service"
)

FOUND=0
for path in "${SYSTEMD_PATHS[@]}"; do
  if [ -f "$path" ]; then
    cp -v "$path" "$WORK_DIR/systemd/"
    success "Backed up: $path"
    FOUND=1
  fi
done

if [ "$FOUND" -eq 0 ]; then
  warning "No nginx.service file found in common locations"
fi


# ===== Step 6: Backup dependencies =====
step 6 "Backing up nginx shared libraries..."
mkdir -p "$WORK_DIR/libs"
ldd "$NGINX_BIN" | awk '{print $3}' | while read -r lib; do
  if [[ -f "$lib" ]]; then
    cp -v "$lib" "$WORK_DIR/libs/"
  fi
done
success "Shared libraries backed up"

# ====== Step 7. Create tarball ======
step 7 "Creating backup archive: $BACKUP_TAR"

# Ensure output directory is writable
OUT_DIR=$(dirname "$BACKUP_TAR")
if [[ ! -w "$OUT_DIR" ]]; then
  error_exit "No write permission to output directory: $OUT_DIR"
fi

# Remove existing backup file if exists
if [[ -f "$BACKUP_TAR" ]]; then
  warning "Existing backup file found, removing: $BACKUP_TAR"
  rm -f "$BACKUP_TAR" || error_exit "Failed to remove old backup file"
fi

# Create the tar.gz
tar czf "$BACKUP_TAR" -C /tmp nginx-backup || error_exit "Tar archive creation failed"

success "Backup archive created"


# ===== Step 8: Cleanup =====
step 8 "Cleaning up temporary files..."
rm -rf "$WORK_DIR"
success "Cleanup done"

echo_color "$MAGENTA" "[DONE] Nginx backup completed successfully: $BACKUP_TAR"
