#!/bin/bash
#Purpose: create/update Packages.gz for all debian repos
#


for i in $(echo /var/www/html/bitaccess/dists/{xenial,focal}/{release/stage{1..5},qa,staging,development}/binary-all);do
    # make sure the newest file is the Packages.gz file
    if ! ls -dlrt $i/* 2>/dev/null|tail -1|grep -q $i/Packages.gz;then
        echo "Creating $i/Packages.gz"
        cd $i
        dpkg-scanpackages . 2>/dev/null| gzip -c9  > Packages.gz
    fi
done
