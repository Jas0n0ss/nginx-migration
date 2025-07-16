# NGINX 1.25.1 RPM with Dynamic Modules & LuaJIT

## 🚀 Features

This custom RPM includes:

- **NGINX 1.25.1**
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

---

## 📦 Installation

```bash
# sudo rpm -ivh nginx-1.25.1-1.x86_64.rpm
sudo dnf localinstall nginx-1.25.1-1.x86_64.rpm
```

Enable and start NGINX:

```bash
sudo systemctl enable --now nginx
```

------

## ⚙️ Configuration

Edit main config:

```bash
/etc/nginx/nginx.conf
```

To enable dynamic modules, add to the top of your config:

```nginx
load_module modules/ngx_http_geoip2_module.so;
load_module modules/ndk_http_module.so;
load_module modules/ngx_http_lua_module.so;
load_module modules/ngx_http_vhost_traffic_status_module.so;
```

------

## 🔧 How to Build

### 1. Install Dependencies

```bash
sudo dnf install -y rpm-build gcc make git \
  pcre-devel zlib-devel openssl-devel \
  luajit luajit-devel systemd-devel \
  readline-devel autoconf automake libtool
```

### 2. Download NGINX Source

```bash
cd ~/rpmbuild/SOURCES
wget http://nginx.org/download/nginx-1.25.1.tar.gz
```

### 3. Place the `nginx.spec`

Save the provided `nginx.spec` file to:

```bash
~/rpmbuild/SPECS/nginx.spec
```

### 4. Build RPM

```bash
rpmbuild -ba ~/rpmbuild/SPECS/nginx.spec
```

The RPMs will be in:

```bash
~/rpmbuild/RPMS/x86_64/
```

------

## 📂 Paths

- Config: `/etc/nginx/nginx.conf`
- Modules: `/usr/nginx/modules/`
- Lua libs: `/usr/nginx/lib/lua/resty/`
- Logs: `/var/log/nginx/`

## 

