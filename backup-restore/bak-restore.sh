#!/bin/bash

set -euo pipefail

show_help() {
    cat <<EOF
Usage:
  $0 --backup --output <output-dir> [--static-dir <path>] [--verbose]
  $0 --restore --input <backup-tgz-file> [--restore-nginx-dir <path>] [--restore-static-dir <path>] [--verbose]

Description:
  Backup or restore Nginx configuration and static files.

Backup mode:
  --output           Output base directory for backup (required)
  --static-dir       Static files directory to backup (default: /data/static)
  --verbose          Enable verbose output

Restore mode:
  --input            Input .tgz backup file to restore from (required)
  --restore-nginx-dir Directory to restore nginx config to (default: /etc/nginx)
  --restore-static-dir Directory to restore static files to (default: /data/static)
  --verbose          Enable verbose output
EOF
}

# Defaults
MODE=""
OUTBASE=""
INPUT=""
STATIC_DIR="/data/static"
RESTORE_NGINX_DIR="/etc/nginx"
RESTORE_STATIC_DIR="/data/static"
VERBOSE=false
TMP_CONF="/tmp/nginx-dump.conf"
HOSTNAME="$(hostname -s)"
ARCHIVE="/tmp/${HOSTNAME}-nginx-backup-$(date +%Y%m%d%H%M%S).tgz"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --backup) MODE="backup"; shift ;;
        --restore) MODE="restore"; shift ;;
        --output) OUTBASE="$2"; shift 2 ;;
        --input) INPUT="$2"; shift 2 ;;
        --static-dir) STATIC_DIR="$2"; shift 2 ;;
        --restore-nginx-dir) RESTORE_NGINX_DIR="$2"; shift 2 ;;
        --restore-static-dir) RESTORE_STATIC_DIR="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
done

log() {
    $VERBOSE && echo "$1"
}

backup() {
    if [[ -z "$OUTBASE" ]]; then
        echo "Error: --output is required for backup"
        exit 1
    fi

    mkdir -p "$OUTBASE/etc/nginx"
    mkdir -p "$OUTBASE/static"

    echo "Running 'nginx -T' to capture active configuration"
    if ! nginx -T > "$TMP_CONF" 2>&1; then
        echo "Error: nginx -T failed. Please check nginx config."
        exit 1
    fi

    echo "Backing up active config files from nginx -T output..."
    grep '^# configuration file ' "$TMP_CONF" | awk '{print $4}' | while read -r conf_file; do
        if [[ -f "$conf_file" ]]; then
            target="$OUTBASE/etc/nginx/${conf_file#/etc/nginx/}"
            mkdir -p "$(dirname "$target")"
            cp -a "$conf_file" "$target"
            log "→ Saved: $conf_file"
        fi
    done

    echo "Backing up entire /etc/nginx directory (in case extra useful configs exist)..."
    rsync -a --exclude='*.swp' --exclude='*.bak' --exclude='*.tmp' /etc/nginx/ "$OUTBASE/etc/nginx-full/"
    log "→ Full config backup at: $OUTBASE/etc/nginx-full"

    if [[ -d "$STATIC_DIR" ]]; then
        echo "Backing up static files from $STATIC_DIR"
        cp -a "$STATIC_DIR" "$OUTBASE/static"
    else
        echo "Warning: static directory $STATIC_DIR not found, skipping."
    fi

    echo "Creating archive..."
    tar -czf "$ARCHIVE" -C "$OUTBASE" .
    chmod 644 "$ARCHIVE"

    echo "✅ Backup complete:"
    echo " - Archive: $ARCHIVE"
}

restore() {
    if [[ -z "$INPUT" ]]; then
        echo "Error: --input is required for restore"
        exit 1
    fi

    if [[ ! -f "$INPUT" ]]; then
        echo "Error: Input file $INPUT does not exist."
        exit 1
    fi

    TMP_RESTORE_DIR="/tmp/${HOSTNAME}-restore-$$"
    mkdir -p "$TMP_RESTORE_DIR"
    tar -xzf "$INPUT" -C "$TMP_RESTORE_DIR"

    echo "Backing up existing $RESTORE_NGINX_DIR to ${RESTORE_NGINX_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$RESTORE_NGINX_DIR" "${RESTORE_NGINX_DIR}.bak.$(date +%Y%m%d%H%M%S)"

    echo "Restoring nginx config to $RESTORE_NGINX_DIR"
    cp -a "$TMP_RESTORE_DIR/etc/nginx/." "$RESTORE_NGINX_DIR/"

    if [[ -d "$TMP_RESTORE_DIR/static" ]]; then
        echo "Restoring static files to $RESTORE_STATIC_DIR"
        mkdir -p "$RESTORE_STATIC_DIR"
        cp -a "$TMP_RESTORE_DIR/static/." "$RESTORE_STATIC_DIR/"
    else
        echo "Warning: static backup not found in archive, skipping static restore."
    fi

    echo "✅ Restore complete."
    rm -rf "$TMP_RESTORE_DIR"
}

# Main execution
if [[ "$MODE" == "backup" ]]; then
    backup
elif [[ "$MODE" == "restore" ]]; then
    restore
else
    echo "Error: must specify --backup or --restore"
    show_help
    exit 1
fi
