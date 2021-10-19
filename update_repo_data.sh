#!/bin/bash
#Purpose: create/update Packages.gz for all debian repos
#

PREFIX=/var/www/html/bitaccess

cd $PREFIX || exit

for i in $(echo dists/{xenial,focal}/{release/stage{1..5},qa,staging,development}/binary-all);do
    # make sure the newest file is the Packages.gz file
    # dpkg-scanpackages dists/qa/binary-all | gzip -c9 >dists/qa/binary-all/Packages.gz
    if ! ls -dlrt $i/* 2>/dev/null|tail -1|grep -q $i/Packages.gz;then
        echo "Creating $PREFIX/$i/Packages.gz"
        [ -n "$DEBUG" ] && echo dpkg-scanpackages $i \| gzip -c9 \>$i/Packages.gz && echo
        [ -z "$DEBUG" ] && dpkg-scanpackages $i 2>/dev/null | gzip -c9 >$i/Packages.gz
    fi
done
