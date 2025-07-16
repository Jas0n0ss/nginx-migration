# Nginx Installation, Backup & Restore Guide

---

## 1. Nginx Installation

### 1. Install Dependencies

For CentOS/RHEL:

```bash
sudo dnf install -y rpm-build gcc make git \
  pcre-devel zlib-devel openssl-devel \
  luajit luajit-devel systemd-devel \
  readline-devel autoconf automake libtool
```

### 2. Download Nginx Source

```bash
cd ~/rpmbuild/SOURCES
wget http://nginx.org/download/nginx-1.25.1.tar.gz
```

### 3. Prepare SPEC File

Save the `nginx.spec` file to:

```bash
~/rpmbuild/SPECS/nginx.spec
```

### 4. Build RPM Package

```bash
rpmbuild -ba ~/rpmbuild/SPECS/nginx.spec
```

The RPM package will be generated in:

```bash
~/rpmbuild/RPMS/x86_64/
```

### 5. Install Nginx

```bash
sudo dnf localinstall nginx-1.25.1-1.x86_64.rpm
sudo systemctl enable --now nginx
```

### 6. Enable Dynamic Modules (if needed)

Edit `/etc/nginx/nginx.conf` and add at the top:

```nginx
load_module modules/ngx_http_geoip2_module.so;
load_module modules/ndk_http_module.so;
load_module modules/ngx_http_lua_module.so;
load_module modules/ngx_http_vhost_traffic_status_module.so;
```

---

## 2. Nginx Config & Static Files Backup and Restore

### 1. Backup

#### Script Description

- `backup-restore/ngx.sh` supports backing up Nginx config and static directory (default `/data/static`).
- The backup will split config files, keep original paths, and archive them.

#### Usage

```bash
./ngx.sh --backup --output <backup_dir> [--perm <permission>] [--static-dir <static_dir>] [--verbose]
```

- `--output`: required, output directory
- `--perm`: optional, config file permission (e.g. 0644)
- `--static-dir`: optional, static directory, default `/data/static`
- `--verbose`: optional, show detailed logs

**Example:**

```bash
./ngx.sh --backup --output /tmp/nginx_backup --perm 0644 --static-dir /data/static --verbose
```

The backup archive will be generated as `/tmp/<hostname>-nginx-backup-conf-with-data-static.tgz` by default.

---

### 2. Restore

#### Usage

```bash
./ngx.sh --restore --input <backup_archive.tgz> [--restore-nginx-dir <nginx_conf_dir>] [--restore-static-dir <static_dir>] [--verbose]
```

- `--input`: required, backup archive file
- `--restore-nginx-dir`: optional, restore Nginx config dir, default `/etc/nginx`
- `--restore-static-dir`: optional, restore static dir, default `/data/static`
- `--verbose`: optional, show detailed logs

**Example:**

```bash
./ngx.sh --restore --input /tmp/nginx-backup.tgz --restore-nginx-dir /etc/nginx --restore-static-dir /data/static --verbose
```

---

## 3. Notes

- Make sure the `nginx` command is available for backup.
- Restore will overwrite config and static files in the target directory. Ensure data safety before proceeding.
- It is recommended to stop Nginx before restoring and start it after.
- Static directory is optional; if not present, it will be skipped.
- For more features and parameters, see [backup-restore/README.md](backup-restore/README.md) and [rpmbuild/README.md](rpmbuild/README.md).

---

## 4. Common Paths

- Config file: `/etc/nginx/nginx.conf`
- Modules directory: `/usr/nginx/modules/`
- Static directory: `/data/static`
- Log directory: `/var/log/nginx/`