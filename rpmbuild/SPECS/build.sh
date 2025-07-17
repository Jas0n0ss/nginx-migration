#!/bin/bash

set -e

show_help() {
  echo "Usage: $0 --name <nginx|tengine> --pkgversion <version>"
  echo
  echo "Options:"
  echo "  --name         Software name: nginx or tengine"
  echo "  --pkgversion   Version number, e.g. 1.25.0 or 3.1.0"
  echo "  --help         Show this help message"
  exit 0
}

# Default values
SOFTWARE="nginx"
VERSION="1.25.0"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      SOFTWARE="$2"
      shift 2
      ;;
    --pkgversion)
      VERSION="$2"
      shift 2
      ;;
    --help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# Validate input
if [[ -z "$SOFTWARE" || -z "$VERSION" ]]; then
  echo "Error: --name and --pkgversion are required."
  show_help
fi

# Only allow nginx or tengine
if [[ "$SOFTWARE" != "nginx" && "$SOFTWARE" != "tengine" ]]; then
  echo "Invalid software name: $SOFTWARE"
  echo "Only 'nginx' or 'tengine' is allowed."
  exit 1
fi

echo "📦 Building RPM for $SOFTWARE $VERSION ..."
rpmbuild -ba nginx-custom.spec --define="build_target ${SOFTWARE},${VERSION}"

echo "✅ Build completed: $SOFTWARE-$VERSION"