#!/bin/bash
#Purpose: delete obsolete branches no longer used
#

MAXAGE=${1:-90}

TOPPATH=/var/www/html/bitaccess/dists

for i in $(find ${TOPPATH}/{upload/,}* -maxdepth 0 -type d);do
    BRANCH=${i##*/};
    echo ":development:qa:staging:stage1:stage2:stage3:stage4:stage5:upload:"|grep -q ":$BRANCH:" && continue
    find $i -mtime -$MAXAGE 2>&1|grep -q . && continue # not yet old enough
    echo "rm -rf $i"
done
