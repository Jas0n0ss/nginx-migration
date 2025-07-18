# NGINX / Tengine RPM with Dynamic Modules & LuaJIT

## 🚀 Features

This custom RPM includes (based on version selected):

- **NGINX 1.x.x** or **Tengine 3.x.x**
- Dynamic modules:
  - `ngx_http_geoip2_module` (GeoIP2 support)
  - `nginx-module-vts` (traffic monitoring)
  - `ngx_devel_kit` (for Lua support)
  - `lua-nginx-module` (Lua scripting support)
- Lua libraries:
  - `lua-resty-core`
  - `lua-resty-lrucache`
- Systemd service integration
- Built with **LuaJIT**

------

## 📦 Installation

```bash
# Install the RPM (example for NGINX):
sudo dnf localinstall nginx-1.25.0-1.x86_64.rpm

# Or for Tengine:
sudo dnf localinstall tengine-3.1.0-1.x86_64.rpm
```

Enable and start the service:

```bash
sudo systemctl enable --now nginx
```

------

## 🔧 How to Build

### 1. Install Dependencies

```bash
# Centos or RedHat 9
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf groupinstall -y "Development Tools"
dnf install -y gcc gcc-c++ make autoconf automake libtool \
    pcre pcre-devel zlib zlib-devel openssl openssl-devel \
    libaio-devel libatomic libatomic_ops-devel \
    libmaxminddb libmaxminddb-devel \
    gperftools gperftools-devel \
    luajit luajit-devel \
    perl-devel perl-ExtUtils-Embed \
    wget unzip git which \
    perl readline-devel systemd-devel
```

### 2. Download Sources

```bash
cd ~/rpmbuild/SOURCES

# If building NGINX
wget http://nginx.org/download/nginx-1.25.0.tar.gz

# If building Tengine
wget http://tengine.taobao.org/download/tengine-3.1.0.tar.gz
```

### 3. Prepare SPEC File

Save the correct spec file to:

```bash
# For NGINX
cp rpmbuild/SPECS/nginx.spec ~/rpmbuild/SPECS/nginx.spec

# For Tengine
cp rpmbuild/SPECS/tengine.spec ~/rpmbuild/SPECS/tengine.spec
```

------

### 4. Build with `build.sh` Script

The script automatically detects whether to use `nginx.spec` or `tengine.spec` based on the environment variable `TENGINE`.

#### ✅ Example: Build NGINX RPM

```bash
# scripts/build.sh --help
NGINX=1.25.0 scripts/build.sh
TENGINE=3.1.0 scripts/build.sh
#
TENGINE=3.1.0 GEOIP2=3.4 VTS=0.2.4 \
DEVEL_KIT=0.3.4 LUA_NGINX=0.10.28 LUA_RESTY_CORE=0.1.24 \
LUA_RESTY_LRUCACHE=0.13 scripts/build.sh
```

> 💡 At least one of `NGINX` or `TENGINE` must be defined.
>  The script will automatically choose `nginx.spec` or `tengine.spec` accordingly.

------

### 5. RPM Output

After building, you'll find the RPM(s) here:

```bash
~/rpmbuild/RPMS/x86_64/
```

------

## 📂 Installed Paths

| File / Directory            | Description                       |
| --------------------------- | --------------------------------- |
| `/etc/nginx/nginx.conf`     | Main configuration file           |
| `/usr/nginx/modules/`       | Dynamic modules (.so files)       |
| `/usr/nginx/lib/lua/resty/` | Lua libraries (`resty-core`, etc) |
| `/var/log/nginx/`           | Logs                              |

### 6. Backup & Install Nginx

```bash
# backup 
tar cvzf /tmp/`hostname`-conf-data.tgz /etc/nginx /data/static
# restore
tar xf <hostname>-conf-data.tgz 
cp -r etc/nginx /etc && cp -r data/static /data
wget https://github.com/Jas0n0ss/ngx-migration/releases/download/v1.0/nginx-1.25.0-1.el9.x86_64.rpm
sudo dnf localinstall nginx-1.28.0-1.el9.x86_64.rpm -y
sudo systemctl enable --now nginx
sudo systemctl status nginx 
```

### 7. Enable Dynamic Modules (if needed)

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
