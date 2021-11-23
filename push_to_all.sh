#!/bin/bash
#Purpose: copy the latest version of ba-btm-software to all stages
#         Only to be used during devvelopment/testing
#


LATEST=$(ls /var/www/html/bitaccess/dists/xenial/development/binary-all/ba-btm-software-*|sort --version-sort|tail -1)
for i in qa staging stage{1..5};do
    rsync -av $LATEST /var/www/html/bitaccess/dists/xenial/$i/binary-all/
    rm -f /var/www/html/bitaccess/dists/xenial/$i/binary-all/Packages.gz
done
/root/bin/update_repo_data.sh
