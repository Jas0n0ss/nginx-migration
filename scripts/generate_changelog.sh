#!/bin/bash
# filepath: /Users/bohu/ngx-migration/scripts/generate_changelog.sh

echo "* $(date '+%a %b %d %Y') $(git config user.name) - $(grep Version rpmbuild/SPECS/nginx.spec | awk '{print $2}')-1"
git log -1 --pretty=format:"- %s"
