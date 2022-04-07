#!/bin/bash
#Purpose: create/update Packages.gz for all debian repos
#

#First check if any new package is in upload
for PACKAGE in $((cd /var/www/html/bitaccess/dists/upload/;ls *.deb)|sed 's/\(^[a-zA-Z-]*\)-[0-9]*[-\.]*.*/\1/'|sort -u);do
    LATEST=$(ls /var/www/html/bitaccess/dists/upload/${PACKAGE}*.deb|sort --version-sort|tail -1)
    if [ ! -e /var/www/html/bitaccess/dists/development/binary-all/${LATEST##*/} ];then
        echo "copying $LATEST to /var/www/html/bitaccess/dists/development/"
        cp -av $LATEST /var/www/html/bitaccess/dists/development/binary-all/
        rm -f /var/www/html/bitaccess/dists/development/binary-all/Packages.gz
    fi
done

PREFIX=/var/www/html/bitaccess

cd $PREFIX || exit

exit_rc=0
[ -z "$TMPDIR" ] && TMPDIR=$(eval echo ~/tmp)
[ ! -d "$TMPDIR" ] && mkdir -p $TMPDIR && chmod 700 $TMPDIR
RESULT=$TMPDIR/result_file.log

for i in $(echo dists/{xenial,focal}/{stage{1..5},qa,staging,development}/binary-all);do
    # make sure the newest file is the Packages.gz file
    # dpkg-scanpackages dists/qa/binary-all | gzip -c9 >dists/qa/binary-all/Packages.gz
    if ! ls -dlrt $i/* 2>/dev/null|tail -1|grep -q $i/Packages.gz;then
        echo "Creating $PREFIX/$i/Packages.gz"
        if [ -z "$DEBUG" ];then
            #dpkg-scanpackages $i 2>/dev/null | gzip -c9 >$i/Packages.gz
            dpkg-scanpackages $i 2>$RESULT| gzip -c9 >$i/Packages.gz
            save_rc=${PIPESTATUS[0]};[ $exit_rc -lt $save_rc ] && exit_rc=$save_rc
            if [ $save_rc -ne 0 ];then
                cat $RESULT
                echo -e "****************\n**************** FAILURE on line $BASH_SOURCE:$LINENO - dpkg-scanpackages $i\n****************\n"
                rm -f $i/Packages.gz
            fi
        else
            echo dpkg-scanpackages $i \| gzip -c9 \>$i/Packages.gz && echo
        fi
    fi
done
exit $exit_rc
