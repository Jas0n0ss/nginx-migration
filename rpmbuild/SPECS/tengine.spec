Name:           tengine
Version:        3.1.0
Release:        1%{?dist}
Summary:        High-performance web server based on nginx with extended features

License:        BSD
URL:            https://tengine.taobao.org/
Source0:        tengine-%{version}.tar.gz
Source1:        tengine.service

%global _lockdir /var/lock

BuildArch:      x86_64
BuildRequires:  gcc, make, automake, autoconf, libtool
BuildRequires:  pcre-devel, zlib-devel, openssl-devel
BuildRequires:  systemd-devel, readline-devel, perl, git
BuildRequires:  luajit, luajit-devel

Requires:       pcre, zlib, openssl, systemd, luajit

%description
Tengine 3.1.0 based on nginx with extended modules, dynamic module support, and LuaJIT integration.

%prep
echo "Cleaning old source directories..."
rm -rf %{_builddir}/ngx_http_geoip2_module-3.4
rm -rf %{_builddir}/nginx-module-vts-0.2.4
rm -rf %{_builddir}/ngx_devel_kit-0.3.4
rm -rf %{_builddir}/lua-nginx-module-0.10.28

echo "Cloning and packing dynamic modules..."

git clone --depth 1 https://github.com/leev/ngx_http_geoip2_module.git %{_builddir}/ngx_http_geoip2_module-3.4
tar czf %{_sourcedir}/ngx_http_geoip2_module-v3.4.tar.gz -C %{_builddir} ngx_http_geoip2_module-3.4

git clone --depth 1 https://github.com/vozlt/nginx-module-vts.git %{_builddir}/nginx-module-vts-0.2.4
tar czf %{_sourcedir}/nginx-module-vts-v0.2.4.tar.gz -C %{_builddir} nginx-module-vts-0.2.4

git clone --depth 1 https://github.com/vision5/ngx_devel_kit.git %{_builddir}/ngx_devel_kit-0.3.4
tar czf %{_sourcedir}/ngx_devel_kit-v0.3.4.tar.gz -C %{_builddir} ngx_devel_kit-0.3.4

git clone --depth 1 https://github.com/openresty/lua-nginx-module.git %{_builddir}/lua-nginx-module-0.10.28
tar czf %{_sourcedir}/lua-nginx-module-v0.10.28.tar.gz -C %{_builddir} lua-nginx-module-0.10.28


%setup -q

# unpack dynamic module sources if present
%if %{defined dynamic_modules}
%__foreach module %{dynamic_modules}
tar xzf %{module}.tar.gz
%__endfor
%endif

%build
export LUAJIT_INC=/usr/include/luajit-2.1
export LUAJIT_LIB=/usr/lib64

./configure \
  --prefix=%{_prefix}/tengine \
  --sbin-path=%{_sbindir}/tengine \
  --conf-path=%{_sysconfdir}/tengine/tengine.conf \
  --pid-path=%{_rundir}/tengine.pid \
  --lock-path=%{_lockdir}/tengine.lock \
  --http-log-path=%{_localstatedir}/log/tengine/access.log \
  --error-log-path=%{_localstatedir}/log/tengine/error.log \
  --user=nginx \
  --group=nginx \
  --modules-path=%{_prefix}/tengine/modules \
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
  --with-luajit-inc=$LUAJIT_INC \
  --with-luajit-lib=$LUAJIT_LIB \
  --with-cc-opt="-DNGX_HTTP_HEADERS -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack‑protector‑strong \
  --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC" \
  --with-ld-opt="-Wl,-z,relro -Wl,-z,now -pie -Wl,--disable-new-dtags" \
  --add-dynamic-module=%{_builddir}/ngx_http_geoip2_module-3.4 \
  --add-dynamic-module=%{_builddir}/nginx-module-vts-0.2.4 \
  --add-dynamic-module=%{_builddir}/ngx_devel_kit-0.3.4 \
  --add-dynamic-module=%{_builddir}/lua-nginx-module-0.10.28

make %{?_smp_mflags}

%install
rm -rf %{buildroot}
install -d %{buildroot}%{_lockdir} %{buildroot}%{_rundir}
install -d %{buildroot}%{_sysconfdir}/tengine %{buildroot}%{_sysconfdir}/systemd/system
install -d %{buildroot}%{_prefix}/tengine/modules
install -d %{buildroot}%{_localstatedir}/log/tengine %{buildroot}%{_localstatedir}/run

make install DESTDIR=%{buildroot}

install -m 644 conf/tengine.conf %{buildroot}%{_sysconfdir}/tengine/tengine.conf
install -m 644 conf/mime.types %{buildroot}%{_sysconfdir}/tengine/mime.types
install -m 644 %{SOURCE1} %{buildroot}%{_sysconfdir}/systemd/system/tengine.service

%files
%defattr(-,root,root,-)
%{_sbindir}/tengine
%{_sysconfdir}/tengine/*
%{_sysconfdir}/systemd/system/tengine.service
%{_prefix}/tengine/modules/*.so
%{_prefix}/tengine/html/*
%dir %{_prefix}/tengine/modules
%dir %{_localstatedir}/log/tengine
%dir %{_localstatedir}/run

%pre
getent group nginx > /dev/null || groupadd -r nginx
getent passwd nginx > /dev/null || \
  useradd -r -g nginx -s /sbin/nologin -M -c "nginx user" nginx

%post
chown -R nginx:nginx %{_prefix}/tengine %{_localstatedir}/log/tengine

%clean
rm -rf %{buildroot}

%changelog
* Wed Jul 16 2025 Jas0n0ss <jas0n0ss@hotmail.com> - 3.1.0
- Initial RPM package for Tengine 3.1.0 with dynamic modules and LuaJIT
    - ngx_http_geoip2_module-v3.4
    - nginx-module-vts-v0.2.4
    - lua-nginx-module-v0.10.28
    - ngx_devel_kit-v0.3.4
