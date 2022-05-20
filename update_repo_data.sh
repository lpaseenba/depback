#!/bin/bash
#Purpose: create/update Packages.gz for all debian repos
#

PREFIX=/var/www/html/bitaccess
cd $PREFIX || exit

#First check if any new package is in upload
for i in $(find $PREFIX/dists/upload -type d);do
    STAGE=${i/*upload\//}
    [ "$STAGE" == "$i" ] && STAGE=development
    [ ! -d $PREFIX/dists/$STAGE/binary-all ] && mkdir -p $PREFIX/dists/$STAGE/binary-all
    
    for PACKAGES in $((cd $i;ls *.deb 2>/dev/null)|sed 's/\(^[a-zA-Z-]*\)-[0-9]*[-\.]*.*/\1/'|sort -u);do
        for PACKAGE in $(ls $i/${PACKAGE}*.deb 2>/dev/null|sort --version-sort);do
            if [ ! -e $PREFIX/dists/$STAGE/binary-all/${PACKAGE##*/} ];then
                echo "copying $PACKAGE to $PREFIX/dists/$STAGE/"
                cp -av $PACKAGE $PREFIX/dists/$STAGE/binary-all/
                rm -f $PREFIX/dists/$STAGE/binary-all/Packages.gz
            fi
        done
    done
done

#cleanup
MAXAGE=90 #delete development files older thna 90 days
for i in $(find $PREFIX/dists -type d -name binary-all);do
    STAGE=$(echo ${i/*dists\//}|cut -d/ -f1)
    echo "$STAGE"|grep -Eq "$(echo development qa staging stage{1..5}|tr ' ' '|')" && continue # don't clean the "official" stages
    if find $i -type f -name "*.deb" -mtime +$MAXAGE|grep -q .;then
        find $i -type f -name "*.deb" -mtime +$MAXAGE -delete
        rm -f $i/Packages.gz
        rmdir $i ${i/\/binary-all} &>/dev/null || true
    fi
done


exit_rc=0
[ -z "$TMPDIR" ] && TMPDIR=$(eval echo ~/tmp)
[ ! -d "$TMPDIR" ] && mkdir -p $TMPDIR && chmod 700 $TMPDIR
RESULT=$TMPDIR/result_file.log

LEN=$(echo -n "$PREFIX"|wc -c);let LEN++
for i in $(find $PREFIX/dists/ -type d -name binary-all);do
    # make sure the newest file is the Packages.gz file
    if ! ls -dlrt $i/* 2>/dev/null|tail -1|grep -q $i/Packages.gz;then
        echo "Creating $i/Packages.gz"
        if [ -z "$DEBUG" ];then
            (cd $PREFIX;dpkg-scanpackages ${i:$LEN} 2>$RESULT| gzip -c9 >$i/Packages.gz)
            save_rc=${PIPESTATUS[0]};[ $exit_rc -lt $save_rc ] && exit_rc=$save_rc
            if [ $save_rc -ne 0 ];then
                cat $RESULT
                echo -e "****************\n**************** FAILURE on line $BASH_SOURCE:$LINENO - dpkg-scanpackages ${i:$LEN}\n****************\n"
                rm -f $i/Packages.gz
            fi
        else
            echo \(cd $PWD\;dpkg-scanpackages ${i:$LEN} \| gzip -c9 \>$i/Packages.gz\)
            echo
        fi
    fi
done

exit $exit_rc
