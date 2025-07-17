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

### 5. Backup & Install Nginx

```bash
# backup 
tar cvzf /tmp/`hostname`-conf-data.tgz /etc/nginx /data/static
```

```bash
# restore
tar xf <hostname>-conf-data.tgz 
cp -r etc/nginx /etc && cp -r data/static /data
wget https://github.com/Jas0n0ss/ngx-migration/releases/download/v1.0/nginx-1.25.0-1.el9.x86_64.rpm
sudo dnf localinstall nginx-1.28.0-1.el9.x86_64.rpm -y
sudo systemctl enable --now nginx
sudo systemctl status nginx 
```

### 6. Enable Dynamic Modules (if needed)

Edit `/etc/nginx/nginx.conf` and add at the top:

```nginx
load_module modules/ngx_http_geoip2_module.so;
load_module modules/ndk_http_module.so;
load_module modules/ngx_http_lua_module.so;
load_module modules/ngx_http_vhost_traffic_status_module.so;
```

### 7. Notes

- Make sure the `nginx` command is available for backup.
- Restore will overwrite config and static files in the target directory. Ensure data safety before proceeding.
- It is recommended to stop Nginx before restoring and start it after.
- Static directory is optional; if not present, it will be skipped.
- For more features and parameters, see [backup-restore/README.md](backup-restore/README.md) and [rpmbuild/README.md](rpmbuild/README.md).

### 8. Common Paths

- Config file: `/etc/nginx/nginx.conf`
- Modules directory: `/usr/nginx/modules/`
- Static directory: `/data/static`
- Log directory: `/var/log/nginx/`
