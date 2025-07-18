%{!?nginx_version: %global nginx_version 1.25.0}
%{!?tengine_version: %global tengine_version 3.1.0}
%{!?geoip2_version: %global geoip2_version 3.4}
%{!?vts_version: %global vts_version 0.2.4}
%{!?devel_kit_version: %global devel_kit_version 0.3.4}
%{!?lua_nginx_version: %global lua_nginx_version 0.10.28}
%{!?lua_resty_core_version: %global lua_resty_core_version 0.1.31}
%{!?lua_resty_lrucache_version: %global lua_resty_lrucache_version 0.15}


%global _lockdir /var/lock

Summary: NGINX with Lua and dynamic module support
Name: nginx
Version: %{nginx_version}
Release: 1%{?dist}
License: BSD
URL: http://nginx.org

Source0: https://nginx.org/download/nginx-%{nginx_version}.tar.gz
Source1: nginx.service

BuildArch:      x86_64
BuildRequires: gcc, make, automake, autoconf, libtool
BuildRequires: pcre-devel, zlib-devel, openssl-devel
BuildRequires: systemd-devel, git, which
BuildRequires: readline-devel, perl
BuildRequires: luajit, luajit-devel
Requires: pcre, zlib, openssl, systemd
Requires: luajit

%description
NGINX 1.25.0 with systemd and dynamic module support.
Included dynamic modules:
- ngx_http_geoip2
- nginx-module-vts
- ngx_devel_kit
- lua-nginx-module
Bundled with lua-resty-core and lua-resty-lrucache for Lua support.

%prep
# Clean up previous build directories
rm -rf %{_builddir}/nginx-%{version}
rm -rf %{_builddir}/ngx_http_geoip2_module-%{geoip2_version}
rm -rf %{_builddir}/nginx-module-vts-%{vts_version}
rm -rf %{_builddir}/ngx_devel_kit-%{devel_kit_version}
rm -rf %{_builddir}/lua-nginx-module-%{lua_nginx_version}
rm -rf %{_builddir}/lua-resty-core-%{lua_resty_core_version}
rm -rf %{_builddir}/lua-resty-lrucache-%{lua_resty_lrucache_version}

%setup -q -n nginx-%{nginx_version}

# Download the required sources
wget -c https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/%{geoip2_version}.tar.gz -O gx_http_geoip2_module-%{geoip2_version}.tar.gz
wget -c https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v%{vts_version}.tar.gz -O nginx-module-vts-%{vts_version}.tar.gz
wget -c https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v%{devel_kit_version}.tar.gz -O ngx_devel_kit-%{devel_kit_version}.tar.gz
wget -c https://github.com/openresty/lua-nginx-module/archive/refs/tags/v%{lua_nginx_version}.tar.gz -O lua-nginx-module-%{lua_nginx_version}.tar.gz
wget -c https://github.com/openresty/lua-resty-core/archive/refs/tags/v%{lua_resty_core_version}.tar.gz -O lua-resty-core-%{lua_resty_core_version}.tar.gz
wget -c https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v%{lua_resty_lrucache_version}.tar.gz -O lua-resty-lrucache-%{lua_resty_lrucache_version}.tar.gz

# Extract the downloaded tarballs into the build directory
tar xf gx_http_geoip2_module-%{geoip2_version}.tar.gz -C %{_builddir}
tar xf nginx-module-vts-%{vts_version}.tar.gz -C %{_builddir}
tar xf ngx_devel_kit-%{devel_kit_version}.tar.gz -C %{_builddir}
tar xf lua-nginx-module-%{lua_nginx_version}.tar.gz -C %{_builddir}
tar xf lua-resty-core-%{lua_resty_core_version}.tar.gz -C %{_builddir}
tar xf lua-resty-lrucache-%{lua_resty_lrucache_version}.tar.gz -C %{_builddir}

# extract the main nginx source && cd to the build directory

%build
export LUAJIT_LIB=/usr/lib64
export LUAJIT_INC=/usr/include/luajit-2.1

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
  --with-cc-opt="-DNGX_HTTP_HEADERS -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC" \
  --with-ld-opt="-Wl,-z,relro -Wl,-z,now -pie -Wl,--disable-new-dtags" \
  --add-dynamic-module=%{_builddir}/ngx_http_geoip2_module-%{geoip2_version} \
  --add-dynamic-module=%{_builddir}/nginx-module-vts-%{vts_version} \
  --add-dynamic-module=%{_builddir}/ngx_devel_kit-%{devel_kit_version} \
  --add-dynamic-module=%{_builddir}/lua-nginx-module-%{lua_nginx_version}

make %{?_smp_mflags}

%install
rm -rf %{buildroot}

# Directories
install -d %{buildroot}%{_lockdir}
install -d %{buildroot}%{_rundir}
install -d %{buildroot}%{_sysconfdir}/nginx
install -d %{buildroot}%{_sysconfdir}/systemd/system
install -d %{buildroot}%{_prefix}/nginx/modules
install -d %{buildroot}%{_prefix}/nginx/lib/lua
install -d %{buildroot}%{_localstatedir}/log/nginx
install -d %{buildroot}%{_localstatedir}/run

# Install nginx
make install DESTDIR=%{buildroot}

# Configuration
install -m 644 conf/nginx.conf %{buildroot}%{_sysconfdir}/nginx/nginx.conf
install -m 644 conf/mime.types %{buildroot}%{_sysconfdir}/nginx/mime.types
install -m 644 %{SOURCE1} %{buildroot}%{_sysconfdir}/systemd/system/nginx.service

# Lua libraries
cp -a %{_builddir}/lua-resty-core-0.1.31/lib/resty %{buildroot}/usr/nginx/lib/lua/
cp -a %{_builddir}/lua-resty-lrucache-0.15/lib/resty %{buildroot}/usr/nginx/lib/lua/


%files
%defattr(-,root,root,-)

%{_sbindir}/nginx
%{_sysconfdir}/nginx/*
%{_sysconfdir}/systemd/system/nginx.service

%{_prefix}/nginx/modules/*.so
%{_prefix}/nginx/html/*
%{_prefix}/nginx/lib/lua/*
%{_prefix}/nginx/lib/lua/resty/*

%dir %{_prefix}/nginx
%dir %{_prefix}/nginx/modules
%dir %{_localstatedir}/log/nginx
%dir %{_localstatedir}/run

%pre
if ! id -u nginx >/dev/null 2>&1; then
  groupadd -r nginx || true
  useradd -r -g nginx -s /sbin/nologin -M -c "nginx user" nginx || true
fi


%post
chown -R nginx:nginx %{_prefix}/nginx
chown -R nginx:nginx %{_localstatedir}/log/nginx

%clean
rm -rf %{buildroot}

%changelog
* Wed Jul 16 2025 Jas0n0ss <jas0n0ss@hotmail.com> - 1.25.0
- Initial RPM package for nginx 1.25.0 with dynamic modules and LuaJIT support:
    - ngx_http_geoip2_module-v3.4
    - nginx-module-vts-v0.2.4 
    - lua-nginx-module-v0.10.28
    - ngx_devel_kit-v0.3.4
