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

# Build array of macros to pass to rpmbuild
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

echo "Building RPM with versions:"
echo "$MACROS"

# Use eval to properly expand the string with quotes
eval rpmbuild $MACROS -ba ~/rpmbuild/SOURCES/nginx.spec
