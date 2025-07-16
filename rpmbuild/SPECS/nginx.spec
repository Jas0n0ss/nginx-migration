# nginx.spec - RPM spec file for building Nginx with dynamic modules and systemd support

Name:           nginx
Version:        1.28.0
Release:        1%{?dist}
Summary:        High-performance web server and reverse proxy server
License:        BSD
URL:            http://nginx.org
Source0:        nginx-%{version}.tar.gz
Source1:        nginx.service

BuildArch:      x86_64

# Build dependencies
BuildRequires:  gcc, make, automake, autoconf, libtool, pcre-devel, zlib-devel, openssl-devel
BuildRequires:  systemd-devel, git

# Runtime dependencies
Requires:       pcre, zlib, openssl, systemd

%description
NGINX is a high-performance HTTP server, reverse proxy server, and mail proxy server.
This RPM package includes support for dynamic modules and systemd service management.

%prep
%setup -q

# Extract dynamic modules (ensure these two modules are included in SOURCES)
tar xf %{_sourcedir}/ngx_http_geoip2_module-3.4.tar.gz
tar xf %{_sourcedir}/nginx-module-vts-v0.2.4.tar.gz

%build
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
  --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' \
  --add-dynamic-module=%{_builddir}/ngx_http_geoip2_module-3.4 \
  --add-dynamic-module=%{_builddir}/nginx-module-vts-0.2.4

make %{?_smp_mflags}

%install
rm -rf %{buildroot}

# Create installation directory structure
install -d %{buildroot}%{_lockdir}
install -d %{buildroot}%{_rundir}
install -d %{buildroot}%{_sysconfdir}/nginx
install -d %{buildroot}%{_sysconfdir}/systemd/system
install -d %{buildroot}%{_prefix}/nginx/modules
install -d %{buildroot}%{_localstatedir}/run
install -d %{buildroot}%{_localstatedir}/log/nginx
install -d %{buildroot}%{_localstatedir}/lock

# Install main program
make install DESTDIR=%{buildroot}

# Install default configuration files (optional: replace with spec-configured files)
install -m 644 conf/nginx.conf %{buildroot}%{_sysconfdir}/nginx/nginx.conf
install -m 644 conf/mime.types %{buildroot}%{_sysconfdir}/nginx/mime.types

# Install dynamic modules
install -m 755 objs/*.so %{buildroot}%{_prefix}/nginx/modules/

# Install systemd service file
install -m 644 %{SOURCE1} %{buildroot}%{_sysconfdir}/systemd/system/nginx.service

%files
%defattr(-,root,root,-)

# Main program and configuration files
%{_sbindir}/nginx
%config(noreplace)%{_sysconfdir}/nginx/nginx.conf
%config(noreplace)%{_sysconfdir}/nginx/mime.types
%config(noreplace)%{_sysconfdir}/nginx/fastcgi.conf
%config(noreplace)%{_sysconfdir}/nginx/fastcgi.conf.default
%config(noreplace)%{_sysconfdir}/nginx/fastcgi_params
%config(noreplace)%{_sysconfdir}/nginx/fastcgi_params.default
%config(noreplace)%{_sysconfdir}/nginx/koi-utf
%config(noreplace)%{_sysconfdir}/nginx/koi-win
%config(noreplace)%{_sysconfdir}/nginx/mime.types.default
%config(noreplace)%{_sysconfdir}/nginx/nginx.conf.default
%config(noreplace)%{_sysconfdir}/nginx/scgi_params
%config(noreplace)%{_sysconfdir}/nginx/scgi_params.default
%config(noreplace)%{_sysconfdir}/nginx/uwsgi_params
%config(noreplace)%{_sysconfdir}/nginx/uwsgi_params.default
%config(noreplace)%{_sysconfdir}/nginx/win-utf

# systemd service file
%{_sysconfdir}/systemd/system/nginx.service

# Modules
%{_prefix}/nginx/modules/*.so

# Directory structure
%dir %{_prefix}/nginx/html/
%dir %{_localstatedir}/log/nginx
%dir %{_localstatedir}/run

# HTML example files
%{_prefix}/nginx/html/50x.html
%{_prefix}/nginx/html/index.html


%pre
# Create nginx user (if not already present)
if ! getent passwd nginx &>/dev/null; then
    useradd -r -s /sbin/nologin nginx
fi

%post
# Set permissions
chown -R nginx:nginx %{_prefix}/nginx
chown -R nginx:nginx %{_localstatedir}/log/nginx
chown -R nginx:nginx %{_localstatedir}/run

%clean
rm -rf %{buildroot}

%changelog
* Tue Jul 15 2025 Jas0n0ss - 1.28.0-1
- Initial RPM package for nginx-1.28.0 with dynamic modules: nginx-module-vts-0.2.4 and ngx_http_geoip2_module-3.4

