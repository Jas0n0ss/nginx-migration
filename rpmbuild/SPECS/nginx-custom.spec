# Custom NGINX/Tengine SPEC with Modular Options

%global nginx_version     1.25.0
%global tengine_version   3.1.0
%global geoip2_version    3.4
%global vts_version       0.2.4
%global ndk_version       0.3.4
%global lua_module_version 0.10.28
%global lua_core_version  0.1.31
%global lrucache_version  0.15

# Default value, can be overridden by --define
%global build_target      nginx,%{nginx_version}

Name:           nginx-custom

Version: %{lua:
  local s = rpm.expand('%{build_target}')
  if not s or s == '' then
    print('1.25.0')
  else
    local ver = s:match('^[^,]+,([^,]+)$')
    if not ver or ver == '' then
      print('1.25.0')
    else
      print(ver)
    end
  end
}

Release:        1%{?dist}
Summary:        Custom build of NGINX or Tengine with modules
License:        BSD
URL:            https://nginx.org/

# Select source directory based on build_target
%global main_software %{lua:
  local s = rpm.expand('%{build_target}') or ''
  local sw,ver = s:match('([^,]+),([^,]+)')
  if sw == 'tengine' then
    print('tengine-'..(ver or '3.1.0'))
  else
    print('nginx-'..(ver or '1.25.0'))
  end
}

Source0:        https://nginx.org/download/nginx-%{nginx_version}.tar.gz
Source1:        https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/%{geoip2_version}.tar.gz
Source2:        https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v%{vts_version}.tar.gz
Source3:        https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v%{ndk_version}.tar.gz
Source4:        https://github.com/openresty/lua-nginx-module/archive/refs/tags/v%{lua_module_version}.tar.gz
Source5:        https://github.com/openresty/lua-resty-core/archive/refs/tags/v%{lua_core_version}.tar.gz
Source6:        https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v%{lrucache_version}.tar.gz
Source7:        https://github.com/alibaba/tengine/archive/refs/tags/%{tengine_version}.tar.gz

BuildRequires:  gcc make pcre-devel zlib-devel openssl-devel libxslt-devel gd-devel perl-devel perl-ExtUtils-Embed libedit-devel libmaxminddb-devel libatomic_ops-devel libxml2-devel geoip-devel gperftools-devel systemd-devel
Requires(post): systemd

%description
This package builds a custom version of NGINX or Tengine with GeoIP2, VTS, Lua modules, and more. It includes systemd service integration and log rotation support.

%prep
%setup -q -c -n %{main_software} -a 1 -a 2 -a 3 -a 4 -a 5 -a 6
if [ "%{build_target}" != "nginx,%{nginx_version}" ]; then
    tar -xzf %{SOURCE7}
    mv tengine-%{tengine_version} tengine
    cp -r tengine/* .
fi

%build
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib64/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/lock/subsys/nginx \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-pcre-jit \
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
    --add-module=ngx_http_geoip2_module-%{geoip2_version} \
    --add-module=nginx-module-vts-%{vts_version} \
    --add-module=ngx_devel_kit-%{ndk_version} \
    --add-module=lua-nginx-module-%{lua_module_version}
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot}
mkdir -p %{buildroot}/var/log/nginx
mkdir -p %{buildroot}/run

# Systemd service
mkdir -p %{buildroot}/usr/lib/systemd/system
cat > %{buildroot}/usr/lib/systemd/system/nginx.service << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# logrotate config
mkdir -p %{buildroot}/etc/logrotate.d
cat > %{buildroot}/etc/logrotate.d/nginx << EOF
/var/log/nginx/*log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 nginx adm
    sharedscripts
    postrotate
        /bin/kill -USR1 `cat /run/nginx.pid 2>/dev/null` 2>/dev/null || true
    endscript
}
EOF

# SELinux placeholder
mkdir -p %{buildroot}/usr/share/selinux/packages

# Lua include path
echo 'lua_package_path "/usr/local/share/lua/?.lua;;";' >> %{buildroot}/etc/nginx/nginx.conf

%files
%license LICENSE
%doc README.md
/usr/sbin/nginx
/usr/lib/systemd/system/nginx.service
/etc/nginx/
/etc/logrotate.d/nginx
/var/log/nginx

%post
%systemd_post nginx.service

%preun
%systemd_preun nginx.service

%postun
%systemd_postun_with_restart nginx.service

%changelog
* Thu Jul 18 2025 mcorp Jas0n0ss - %{version}
- Initial build with full NGINX/Tengine module support and all compile flags