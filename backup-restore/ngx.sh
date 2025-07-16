#!/bin/bash

set -euo pipefail

# Display usage help
show_help() {
    cat <<EOF
Usage:
  $0 --backup --output <output-dir> [--perm <mode>] [--static-dir <path>] [--verbose]
  $0 --restore --input <backup-tgz-file> [--restore-nginx-dir <path>] [--restore-static-dir <path>] [--verbose]

Description:
  Backup or restore Nginx configuration and static files.

Backup mode (--backup):
  --output           Output directory for split config files and static files (required)
  --perm             Permission mode for config files, e.g., 0644 (optional)
  --static-dir       Static files directory, default /data/static
  --verbose          Show detailed process
  example: $0 --backup --output /tmp/nginx_backup --perm 0644 --static-dir /data/static --verbose

Restore mode (--restore):
  --input            Input backup tar.gz archive file (required)
  --restore-nginx-dir Directory to restore nginx config, default /etc/nginx
  --restore-static-dir Directory to restore static files, default /data/static
  --verbose          Show detailed process
  example: $0 --restore --input /tmp/backup.tgz --restore-nginx-dir /etc/nginx --restore-static-dir /data/static --verbose

Note:
  Backup generates /tmp/{hostname}-nginx-conf-all.tgz archive
  Restore requires this archive file as input
EOF
}

# Default values
MODE=""
OUTBASE=""
INPUT=""
PERM=""
VERBOSE=false
STATIC_DIR="/data/static"
RESTORE_NGINX_DIR="/etc/nginx"
RESTORE_STATIC_DIR="/data/static"
TMP_CONF="/tmp/nginx-conf-all.conf"
HOSTNAME="$(hostname -s)"
ARCHIVE="/tmp/${HOSTNAME}-nginx-backup-conf-with-data-static.tgz"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backup)
            MODE="backup"
            shift
            ;;
        --restore)
            MODE="restore"
            shift
            ;;
        --output)
            OUTBASE="$2"
            shift 2
            ;;
        --input)
            INPUT="$2"
            shift 2
            ;;
        --perm)
            PERM="$2"
            shift 2
            ;;
        --static-dir)
            STATIC_DIR="$2"
            shift 2
            ;;
        --restore-nginx-dir)
            RESTORE_NGINX_DIR="$2"
            shift 2
            ;;
        --restore-static-dir)
            RESTORE_STATIC_DIR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate mode selection
if [[ "$MODE" != "backup" && "$MODE" != "restore" ]]; then
    echo "Error: must specify either --backup or --restore mode"
    show_help
    exit 1
fi

# Verbose logging function
log() {
    if $VERBOSE; then
        echo "$1"
    fi
}

############################
# Backup function
############################
backup() {
    if [[ -z "$OUTBASE" ]]; then
        echo "Error: --output is required in backup mode"
        exit 1
    fi

    # Check if nginx command is available
    if ! command -v nginx >/dev/null; then
        echo "Error: nginx not found or not in PATH"
        exit 1
    fi

    echo "Running 'nginx -T' to get current nginx config..."
    # Dump full nginx configuration to temporary file
    if ! nginx -T > "$TMP_CONF" 2>&1; then
        echo "Error: 'nginx -T' failed, please check nginx status and config"
        exit 1
    fi

    echo "Splitting configuration files into directory: $OUTBASE/"
    mkdir -p "$OUTBASE/etc/nginx"

    current_path=""
    buffer=""

    # Parse dumped config, split into individual files based on comment markers
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#\ configuration\ file\ (.+):$ ]]; then
            if [ -n "$current_path" ]; then
                full_path="$OUTBASE/$current_path"
                mkdir -p "$(dirname "$full_path")"
                printf "%s\n" "$buffer" > "$full_path"
                [[ -n "$PERM" ]] && chmod "$PERM" "$full_path"
                log "Wrote file: $full_path"
            fi
            # Remove leading slash from path
            current_path="${BASH_REMATCH[1]#/}"
            buffer=""
        else
            [[ -z "$current_path" ]] && current_path="etc/nginx/nginx.conf"
            buffer+="${line}"$'\n'
        fi
    done < "$TMP_CONF"

    # Write last buffered content to file
    if [ -n "$current_path" ]; then
        full_path="$OUTBASE/$current_path"
        mkdir -p "$(dirname "$full_path")"
        printf "%s\n" "$buffer" > "$full_path"
        [[ -n "$PERM" ]] && chmod "$PERM" "$full_path"
        log "Wrote file: $full_path"
    fi

    # Backup static files directory if exists
    if [[ -d "$STATIC_DIR" ]]; then
        log "Copying static files directory $STATIC_DIR to $OUTBASE/static/"
        rm -rf "$OUTBASE/static"
        cp -a "$STATIC_DIR" "$OUTBASE/static"
    else
        echo "Warning: static files directory $STATIC_DIR does not exist, skipping"
    fi

    echo "Creating archive from $OUTBASE ..."
    # Create compressed tarball archive of backup directory
    tar -czf "$ARCHIVE" -C "$OUTBASE" .
    chmod 777 "$ARCHIVE"

    echo "Backup completed:"
    echo "  Config directory: $OUTBASE/"
    echo "  Static files directory: $OUTBASE/static/"
    echo "  Archive file: $ARCHIVE"
}

############################
# Restore function
############################
restore() {
    if [[ -z "$INPUT" ]]; then
        echo "Error: --input is required in restore mode"
        exit 1
    fi

    # Check if input is a regular file ending with .tgz
    if [[ ! -f "$INPUT" || "$INPUT" != *.tgz ]]; then
        echo "Error: --input must be a valid .tgz file"
        exit 1
    fi

    TMP_RESTORE_DIR="/tmp/${HOSTNAME}-nginx-conf-restore-$$"
    log "Extracting archive $INPUT to temporary directory $TMP_RESTORE_DIR"
    mkdir -p "$TMP_RESTORE_DIR"
    tar -xzf "$INPUT" -C "$TMP_RESTORE_DIR"

    SRC_DIR="$TMP_RESTORE_DIR"
    SRC_NGINX_DIR="$SRC_DIR/etc/nginx"

    if [[ ! -d "$SRC_NGINX_DIR" ]]; then
        echo "Error: config directory etc/nginx not found in backup archive"
        rm -rf "$TMP_RESTORE_DIR"
        exit 1
    fi

    echo "Restoring nginx config to: $RESTORE_NGINX_DIR"
    mkdir -p "$RESTORE_NGINX_DIR"
    cp -a "$SRC_NGINX_DIR/." "$RESTORE_NGINX_DIR/"
    echo "Nginx config restore complete."

    SRC_STATIC_DIR="$SRC_DIR/static"
    if [[ -d "$SRC_STATIC_DIR" ]]; then
        echo "Restoring static files to: $RESTORE_STATIC_DIR"
        mkdir -p "$RESTORE_STATIC_DIR"
        cp -a "$SRC_STATIC_DIR/." "$RESTORE_STATIC_DIR/"
        echo "Static files restore complete."
    else
        echo "Warning: static directory 'static' not found in backup archive, skipping static files restore"
    fi

    rm -rf "$TMP_RESTORE_DIR"

    echo "Restore finished."
}

############################
# Main execution
############################
if [[ "$MODE" == "backup" ]]; then
    backup
elif [[ "$MODE" == "restore" ]]; then
    restore
fi
