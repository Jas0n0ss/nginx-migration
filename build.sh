#!/bin/bash

set -e

usage() {
  cat <<EOF
Usage: $0 [--help]

Build RPM with versions specified by environment variables.

Environment variables you can set (optional):
  NGINX          nginx version (used for nginx_version macro)
  TENGINE        tengine version (used for tengine_version macro)
  GEOIP2         geoip2 module version (geoip2_version macro)
  VTS            vts module version (vts_version macro)
  DEVEL_KIT      devel_kit module version (devel_kit_version macro)
  LUA_NGINX      lua-nginx-module version (lua_nginx_version macro)
  LUA_RESTY_CORE lua-resty-core version (lua_resty_core_version macro)
  LUA_RESTY_LRUCACHE lua-resty-lrucache version (lua_resty_lrucache_version macro)

Examples:
  NGINX=1.28.0 GEOIP2=3.5 ./build-nginx.sh
  TENGINE=3.1.0 ./build-nginx.sh
EOF
}

if [[ "$1" == "--help" ]]; then
  usage
  exit 0
fi

# Build macro definitions
MACROS=""

[[ -n "$NGINX" ]] && MACROS+=" -D \"nginx_version $NGINX\""
[[ -n "$TENGINE" ]] && MACROS+=" -D \"tengine_version $TENGINE\""
[[ -n "$GEOIP2" ]] && MACROS+=" -D \"geoip2_version $GEOIP2\""
[[ -n "$VTS" ]] && MACROS+=" -D \"vts_version $VTS\""
[[ -n "$DEVEL_KIT" ]] && MACROS+=" -D \"devel_kit_version $DEVEL_KIT\""
[[ -n "$LUA_NGINX" ]] && MACROS+=" -D \"lua_nginx_version $LUA_NGINX\""
[[ -n "$LUA_RESTY_CORE" ]] && MACROS+=" -D \"lua_resty_core_version $LUA_RESTY_CORE\""
[[ -n "$LUA_RESTY_LRUCACHE" ]] && MACROS+=" -D \"lua_resty_lrucache_version $LUA_RESTY_LRUCACHE\""

if [[ -z "$MACROS" ]]; then
  echo "Error: Please set at least one version environment variable (e.g. NGINX or TENGINE)."
  usage
  exit 1
fi

echo "🛠️  Building RPM with macros:"
echo "$MACROS"
echo
# Ensure rpmbuild directory structure exists
RPMBUILD_ROOT=~/rpmbuild

for dir in BUILD RPMS SOURCES SPECS SRPMS; do
  FULL_PATH="$RPMBUILD_ROOT/$dir"
  if [[ -d "$FULL_PATH" ]]; then
    echo "✅ Directory exists: $FULL_PATH"
  else
    echo "📁 Creating directory: $FULL_PATH"
    mkdir -p "$FULL_PATH"
  fi
done

# Auto download source tarball
if [[ -n "$NGINX" ]]; then
  FILENAME="nginx-${NGINX}.tar.gz"
  URL="http://nginx.org/download/${FILENAME}"
  DEST="$RPMBUILD_ROOT/SOURCES/$FILENAME"

  if [[ -f "$DEST" ]]; then
    echo "✅ NGINX source exists: $DEST"
  else
    echo "⬇️  Downloading NGINX source: $URL"
    wget -q -O "$DEST" "$URL"
    if [[ $? -ne 0 ]]; then
      echo "Failed to download $URL"
      exit 1
    fi
  fi
fi

if [[ -n "$TENGINE" ]]; then
  FILENAME="tengine-${TENGINE}.tar.gz"
  URL="http://tengine.taobao.org/download/${FILENAME}"
  DEST="$RPMBUILD_ROOT/SOURCES/$FILENAME"

  if [[ -f "$DEST" ]]; then
    echo "✅ Tengine source exists: $DEST"
  else
    echo "⬇️  Downloading Tengine source: $URL"
    wget -q -O "$DEST" "$URL"
    if [[ $? -ne 0 ]]; then
      echo "Failed to download $URL"
      exit 1
    fi
  fi
fi


# Choose correct spec file path
SPEC_FILE="$RPMBUILD_ROOT/SPECS/nginx.spec"
if [[ -n "$TENGINE" ]]; then
  SPEC_FILE="$RPMBUILD_ROOT/SPECS/tengine.spec"
fi

# Check if spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
  echo "Spec file not found: $SPEC_FILE"
  exit 1
fi

# Build the RPM
echo "📦 Running: rpmbuild -ba $SPEC_FILE"
eval rpmbuild $MACROS -ba "$SPEC_FILE"

echo "✅ RPM build complete!"
echo "You can find the built RPMs in $RPMBUILD_ROOT/RPMS/"