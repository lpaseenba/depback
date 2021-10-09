#!/bin/bash


for i in $(echo /var/www/html/bitaccess/{release/stage{1..5},qa,staging,development});do
    # make sure the newest file is the Packages.gz file
    if ! ls -dlrt $i/*|tail -1|grep -q $i/Packages.gz;then
        echo "Creating $i/Packages.gz"
        cd $i
        dpkg-scanpackages . 2>/dev/null| gzip -c9  > Packages.gz
    fi
done
