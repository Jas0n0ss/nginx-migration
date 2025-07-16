# NGINX RPM Build Guide

## Key Features and Modules

- **Version**: 1.28.0

- **Dynamic Modules**:
  - `ngx_http_geoip2_module` (GeoIP support)
  - `nginx-module-vts` (Virtual Host Traffic Stats)

## Prerequisites

Ensure your system has the necessary dependencies for building the RPM package:

### Required Packages:

```bash
# On RHEL/CentOS/Fedora
sudo yum groupinstall "Development Tools"
sudo yum install pcre-devel zlib-devel openssl-devel systemd git
```

```bash
# On Ubuntu/Debian:
sudo apt update
sudo apt install build-essential pcre3-dev zlib1g-dev libssl-dev systemd git
```

## Build the RPM Package

1. **Build the RPM**
    After making sure all dependencies are installed, run the following command to build the RPM package:

   ```bash
   dnf groupinstall -y "Development Tools"
   dnf rpm-build rpmdevtools -y
   git clone https://github.com/Jas0n0ss/ngx_backup_restore.git nginx && nginx
   rpmbuild -ba rpmbuild/SPECS/nginx.spec
   ```

   This will compile the NGINX package along with the dynamic modules and systemd service.

   The file should be named something like `/root/rpmbuild/RPMS/x86_64/nginx-1.28.0-1.el9.x86_64.rpm`.

## Install the RPM Package

1. **Install the RPM**
    Use `rpm` to install the package:

   ```bash
   sudo yum localinstall rpmbuild/RPMS/x86_64/nginx-1.28.0-1.x86_64.rpm
   ```

2. **Enable and Start NGINX Service**
    After installation, enable and start the NGINX service with `systemd`:

   ```bash
   sudo systemctl enable nginx
   sudo systemctl start nginx
   ```

3. **Check NGINX Status**
    Verify that NGINX is running:

   ```bash
   sudo systemctl status nginx
   ```
