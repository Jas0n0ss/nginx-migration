Sure! Here’s a simple README in English for your backup/restore script:

---

# Nginx Backup and Restore Script

This script allows you to **backup** and **restore** Nginx configuration files and static content easily.

---

## Features

* Backup Nginx full configuration (using `nginx -T` output)
* Split the config into individual files preserving the original paths
* Backup static files directory (default `/data/static`)
* Create a compressed archive of the backup for easy transport or storage
* Restore Nginx config and static files from the backup archive
* Supports setting file permission during backup
* Verbose mode for detailed logs

---

## Usage

### Backup mode

```bash
./script.sh --backup --output <backup-directory> [--perm <file-permission>] [--static-dir <path>] [--verbose]
```

* `--output` — Directory where config files and static files will be saved (required)
* `--perm` — Permission mode for config files (optional, e.g., `0644`)
* `--static-dir` — Path to static files directory (default: `/data/static`)
* `--verbose` — Show detailed process logs

**Example:**

```bash
./script.sh --backup --output /tmp/nginx_backup --perm 0644 --static-dir /data/static --verbose
```

The script creates a backup archive in `/tmp/<hostname>-nginx-backup-conf-with-data-static.tgz`.

---

### Restore mode

```bash
./script.sh --restore --input <backup-archive.tgz> [--restore-nginx-dir <path>] [--restore-static-dir <path>] [--verbose]
```

* `--input` — Backup archive file to restore from (required)
* `--restore-nginx-dir` — Directory to restore Nginx config files (default: `/etc/nginx`)
* `--restore-static-dir` — Directory to restore static files (default: `/data/static`)
* `--verbose` — Show detailed process logs

**Example:**

```bash
./script.sh --restore --input /tmp/my-backup.tgz --restore-nginx-dir /etc/nginx --restore-static-dir /data/static --verbose
```

---

## Notes

* Backup requires `nginx` command to be available in your PATH.
* The static directory is optional and will be skipped if missing.
* Backup archives include all config files and static files for easy migration or backup.
* Restore will overwrite the existing config and static files in the specified directories.

