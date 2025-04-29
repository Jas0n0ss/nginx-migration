#!/bin/bash
# Offline restore nginx and dependencies with auto-fix for missing libraries
set -e

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Defaults
BACKUP_TAR=""
WORK_DIR="/tmp/nginx-backup"
NGINX_BIN="/usr/sbin/nginx"
CLEAN_OLD=true   # CLEAN is now default
NO_START=false
EXCLUDES=()

# Color output helpers
echo_color() { echo -e "${1}${2}${NC}"; }
step()       { echo_color "$YELLOW" "[Step $1] $2"; }
success()    { echo_color "$GREEN" "[✔] $1"; }
warning()    { echo_color "$YELLOW" "[⚠] $1"; }
error_exit() { echo_color "$RED" "[✖] $1"; exit 1; }

print_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [BACKUP_TAR]

Restore Nginx, modules, configuration, static files, and dependencies.

Options:
  --no-clean           Skip cleanup of old Nginx installation (cleanup is default)
  --no-start           Do not start Nginx after restoring
  --exclude <dir>      Exclude a directory from restoration (can be used multiple times)
  --backup-file <path> Explicitly specify the backup tar file path
  --help               Show this help message and exit

Notes:
  If BACKUP_TAR or --backup-file is not provided, you will be prompted to enter the path interactively.

Examples:
  $0 /root/nginx-backup.tar.gz
  $0 --backup-file /root/nginx.tar.gz --exclude static --no-start --no-clean
EOF
}

# Parse parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-clean)
            CLEAN_OLD=false
            shift
            ;;
        --no-start)
            NO_START=true
            shift
            ;;
        --exclude)
            EXCLUDES+=("$2")
            shift 2
            ;;
        --backup-file)
            BACKUP_TAR="$2"
            shift 2
            ;;
        --help)
            print_help
            exit 0
            ;;
        -*)
            error_exit "Unknown option: $1"
            ;;
        *)
            BACKUP_TAR="$1"
            shift
            ;;
    esac
done

# Prompt for backup tar if not provided
if [ -z "$BACKUP_TAR" ]; then
    echo_color "$YELLOW" "No backup tar path provided."
    read -rp "Please enter the full path to the backup tar file: " BACKUP_TAR
    [ -z "$BACKUP_TAR" ] && error_exit "Backup path is required."
fi

# Step 0. Clean old installation if enabled
if [ "$CLEAN_OLD" = true ]; then
    step 0 "Cleaning up existing nginx installation..."
    systemctl stop nginx || warning "Nginx service not running"
    systemctl disable nginx || true
    rm -f "$NGINX_BIN" || true
    rm -rf /etc/nginx /usr/lib64/nginx /var/cache/nginx /var/log/nginx /var/run/nginx || true
    rm -f /usr/lib/systemd/system/nginx.service || true
    success "Old nginx environment cleaned up"
else
    step 0 "Skipping cleanup of old nginx installation (--no-clean specified)"
fi

# Step 1. Check backup
step 1 "Checking backup package..."
[ ! -f "$BACKUP_TAR" ] && error_exit "Backup package not found: $BACKUP_TAR"
success "Backup package found: $BACKUP_TAR"

# Step 2. Extract backup
step 2 "Extracting backup package..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
tar xzf "$BACKUP_TAR" -C /tmp
success "Backup extracted"

# Check if a directory is excluded
is_excluded() {
    local dir="$1"
    for excl in "${EXCLUDES[@]}"; do
        [[ "$dir" == "$excl" ]] && return 0
    done
    return 1
}

# Step 3. Restore nginx binary and config
if ! is_excluded "nginx"; then
    step 3 "Restoring nginx binary, modules and configuration..."
    mkdir -p /etc/nginx /usr/lib64/nginx
    cp "$WORK_DIR/nginx" "$NGINX_BIN"
    cp -r "$WORK_DIR/modules/"* /usr/lib64/nginx/ 2>/dev/null || true
    cp -r "$WORK_DIR/nginx-conf/"* /etc/nginx/ 2>/dev/null || true
    success "Nginx binary and config restored"
else
    warning "Skipped nginx binary/config restore (--exclude nginx)"
fi

# Step 4. Restore static files
if ! is_excluded "static"; then
    step 4 "Restoring static web data..."
    mkdir -p /data
    cp -r "$WORK_DIR/static" /data/ 2>/dev/null || true
    success "Static files restored"
else
    warning "Skipped static files restore (--exclude static)"
fi

# Step 5. Restore systemd service
if ! is_excluded "nginx.service"; then
    step 5 "Restoring nginx systemd service file..."
    if [ -f "$WORK_DIR/nginx.service" ]; then
        cp "$WORK_DIR/nginx.service" /usr/lib/systemd/system/
        success "Systemd service restored"
    else
        warning "Systemd service file not found in backup, skipping"
    fi
else
    warning "Skipped systemd service restore (--exclude nginx.service)"
fi

# Step 6. Create nginx user if needed
step 6 "Ensuring nginx user exists..."
id nginx >/dev/null 2>&1 || useradd -r -s /sbin/nologin nginx
success "Nginx user ready"

# Step 7. Runtime dirs
step 7 "Preparing runtime directories..."
mkdir -p /var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp} \
         /var/log/nginx /var/run/nginx
chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/run/nginx /data/static || true
success "Runtime directories prepared"

# Step 8. Restore libraries
if ! is_excluded "libs"; then
    step 8 "Restoring required libraries..."
    for src_path in "$WORK_DIR/libs/"*; do
        base_name=$(basename "$src_path")
        dest_path="/lib64/$base_name"
        if [ ! -e "$dest_path" ]; then
            echo_color "$GREEN" "[+] Copying missing library: $base_name"
            cp -a "$src_path" "/lib64/"
        else
            echo_color "$GREEN" "[✓] Library already exists: $base_name"
        fi
    done
    ldconfig
    success "Libraries restored and ldconfig updated"
else
    warning "Skipped library restore (--exclude libs)"
fi

# Step 9. Check for missing libraries
step 9 "Checking nginx dependencies..."
MISSING_LIBS=()
while IFS= read -r line; do
    [[ "$line" == *"not found"* ]] && MISSING_LIBS+=("$(echo "$line" | awk '{print $1}')")
done < <(ldd "$NGINX_BIN")

if [ ${#MISSING_LIBS[@]} -ne 0 ]; then
    error_exit "Missing libraries detected:\n$(printf ' - %s\n' "${MISSING_LIBS[@]}")\nPlease manually install missing libraries!"
fi
success "All dependencies are satisfied"

# Step 10. Start nginx if not skipped
if [ "$NO_START" = false ]; then
    step 10 "Starting nginx service..."
    systemctl daemon-reload
    systemctl enable nginx
    systemctl restart nginx
    success "Nginx service started successfully"
else
    warning "Skipped starting nginx (--no-start specified)"
fi

echo_color "$GREEN" "[✔] Nginx offline restore completed successfully!"
