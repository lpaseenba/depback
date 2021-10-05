#!/bin/bash


for i in $(echo /var/www/html/bitaccess/{release{,/stage{1..9}},qa,staging,development});do
    # make sure the newest file is the Packages.gz file
    ls -dlrt $i/*|tail -1|grep -q $i/Packages.gz || (cd $i;dpkg-scanpackages . | gzip -c9  > Packages.gz)
done
