# NGINX RPM SPEC FILE WITH LUA AND DYNAMIC MODULE SUPPORT

Name:           nginx
Version:        1.25.0
Release:        1%{?dist}
Summary:        High-performance web server and reverse proxy with Lua and dynamic module support

License:        BSD
URL:            http://nginx.org

# Source tarballs for nginx and modules
Source0:        nginx-%{version}.tar.gz
Source1:        nginx.service
Source2:        ngx_http_geoip2_module-v3.4.tar.gz
Source3:        nginx-module-vts-v0.2.4.tar.gz
Source4:        ngx_devel_kit-v0.3.4.tar.gz
Source5:        lua-nginx-module-v0.10.28.tar.gz
Source6:        lua-resty-core-v0.1.31.tar.gz
Source7:        lua-resty-lrucache-v0.15.tar.gz

BuildArch:      x86_64

# Build dependencies
BuildRequires:  gcc, make, automake, autoconf, libtool
BuildRequires:  pcre2-devel, zlib-devel, openssl-devel
BuildRequires:  systemd-devel, git, which
BuildRequires:  readline-devel, perl
BuildRequires:  luajit, luajit-devel

# Runtime dependencies
Requires:       pcre2, zlib, openssl, systemd
Requires:       luajit

%description
# Package description
NGINX 1.25.0 with systemd and dynamic module support.
Included dynamic modules:
- ngx_http_geoip2
- nginx-module-vts
- ngx_devel_kit
- lua-nginx-module
Bundled with lua-resty-core and lua-resty-lrucache for Lua support.

%prep
echo "Cleaning previous build directories..."
rm -rf %{_builddir}/ngx_http_geoip2_module-*
rm -rf %{_builddir}/nginx-module-vts-*
rm -rf %{_builddir}/ngx_devel_kit-*
rm -rf %{_builddir}/lua-nginx-module-*
rm -rf %{_builddir}/lua-resty-core-*
rm -rf %{_builddir}/lua-resty-lrucache-*

echo "Cloning and packing dynamic modules..."

modules=(
  "https://github.com/leev/ngx_http_geoip2_module.git v3.4 ngx_http_geoip2_module"
  "https://github.com/vozlt/nginx-module-vts.git v0.2.4 nginx-module-vts"
  "https://github.com/vision5/ngx_devel_kit.git v0.3.4 ngx_devel_kit"
  "https://github.com/openresty/lua-nginx-module.git v0.10.28 lua-nginx-module"
  "https://github.com/openresty/lua-resty-core.git v0.1.31 lua-resty-core"
  "https://github.com/openresty/lua-resty-lrucache.git v0.15 lua-resty-lrucache"
)

for entry in "${modules[@]}"; do
  set -- $entry
  url=$1
  version=$2
  name=$3

  dirname="${name}-${version}"
  dir="%{_builddir}/${dirname}"
  tarball="%{_sourcedir}/${dirname}.tar.gz"

  echo "→ Processing $name"

  if [ ! -d "$dir" ]; then
    echo "  - Cloning $url"
    if git ls-remote --tags "$url" | grep -q "refs/tags/${version}$"; then
      git clone --depth 1 --tag "$version" "$url" "$dir"
    else
      echo "Tag $version not found, defaulting to master"
      git clone --depth 1 "$url" "$dir"
    fi
  fi

  if [ ! -f "$tarball" ]; then
    echo "  - Creating $tarball"
    tar czf "$tarball" -C "%{_builddir}" "$dirname"
  fi
done

# Unpack the main source and modules
%setup -q

tar xf %{SOURCE2}
tar xf %{SOURCE3}
tar xf %{SOURCE4}
tar xf %{SOURCE5}
tar xf %{SOURCE6}
tar xf %{SOURCE7}

%build
# Set LuaJIT environment variables for building
export LUAJIT_LIB=/usr/lib64
export LUAJIT_INC=/usr/include/luajit-2.1

# Configure nginx with various modules and options
./configure \
  --prefix=%{_prefix}/nginx \
  --sbin-path=%{_sbindir}/nginx \
  --conf-path=%{_sysconfdir}/nginx/nginx.conf \
  --pid-path=%{_rundir}/nginx.pid \
  --lock-path=%{_lockdir}/nginx.lock \
  --http-log-path=%{_localstatedir}/log/nginx/access.log \
  --error-log-path=%{_localstatedir}/log/nginx/error.log \
  --user=nginx \
  --group=nginx \
  --modules-path=%{_prefix}/nginx/modules \
  --with-compat \
  --with-file-aio \
  --with-threads \
  --with-http_addition_module \
  --with-http_auth_request_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_mp4_module \
  --with-http_random_index_module \
  --with-http_realip_module \
  --with-http_secure_link_module \
  --with-http_slice_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-stream \
  --with-stream_realip_module \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-google_perftools_module \
  --with-debug \
  --with-cc-opt='-DNGX_HTTP_HEADERS -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' \
  --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie -Wl,--disable-new-dtags' \
  --add-dynamic-module=%{_builddir}/ngx_http_geoip2_module-3.4 \
  --add-dynamic-module=%{_builddir}/nginx-module-vts-0.2.4 \
  --add-dynamic-module=%{_builddir}/ngx_devel_kit-0.3.4 \
  --add-dynamic-module=%{_builddir}/lua-nginx-module-0.10.28

# Build nginx and modules
make %{?_smp_mflags}

%install
# Clean previous install root
rm -rf %{buildroot}

# Create necessary directories in the buildroot
install -d %{buildroot}%{_lockdir}
install -d %{buildroot}%{_rundir}
install -d %{buildroot}%{_sysconfdir}/nginx
install -d %{buildroot}%{_sysconfdir}/systemd/system
install -d %{buildroot}%{_prefix}/nginx/modules
install -d %{buildroot}%{_prefix}/nginx/lib/lua
install -d %{buildroot}%{_localstatedir}/log/nginx
install -d %{buildroot}%{_localstatedir}/run

# Install nginx and modules to buildroot
make install DESTDIR=%{buildroot}

# Install default configuration files and systemd service
install -m 644 conf/nginx.conf %{buildroot}%{_sysconfdir}/nginx/nginx.conf
install -m 644 conf/mime.types %{buildroot}%{_sysconfdir}/nginx/mime.types
install -m 644 %{SOURCE1} %{buildroot}%{_sysconfdir}/systemd/system/nginx.service

# Copy Lua libraries for nginx Lua module
cp -r lua-resty-core-0.1.31/lib/resty %{buildroot}%{_prefix}/nginx/lib/lua/
cp -r lua-resty-lrucache-0.15/lib/resty %{buildroot}%{_prefix}/nginx/lib/lua/

%files
%defattr(-,root,root,-)

# Main nginx binary and configuration
%{_sbindir}/nginx
%{_sysconfdir}/nginx/*
%{_sysconfdir}/systemd/system/nginx.service

# Dynamic modules, html files, and Lua libraries
%{_prefix}/nginx/modules/*.so
%{_prefix}/nginx/html/*
%{_prefix}/nginx/lib/lua/**

# Directory declarations
%dir %{_prefix}/nginx
%dir %{_prefix}/nginx/modules
%dir %{_localstatedir}/log/nginx
%dir %{_localstatedir}/run

%post
# Set ownership for nginx directories after install
chown -R nginx:nginx %{_prefix}/nginx
chown -R nginx:nginx %{_localstatedir}/log/nginx

%clean
# Clean up buildroot after build
rm -rf %{buildroot}

%changelog
* Wed Jul 16 2025 Jas0n0ss <jas0n0ss@hotmail.com> - 1.25.0-1
- Initial RPM package for nginx 1.25.0 with Lua and dynamic module support
