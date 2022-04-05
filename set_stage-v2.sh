#!/bin/bash
#Purpose: show what stage any given package is at
#
#v2 - version that handles versions
#



DIRPATH=/var/www/html/bitaccess/dists
OS_CODENAME=(xenial focal)
STAGES=($(echo {development,qa,staging,stage{1..5}}))
#PACKAGES=("docker_cloud_btm" "provisioner") # package name can't include "_"
#PACKAGES=("docker-btm" "provisioner")
#PACKAGES=(ba-btm-software ba-test)

unset PACKAGES
PACKAGES=(ba-btm-software) # default first package
#check if it exist any other packages
for i in $DIRPATH/*/development/binary-all/*deb;do
    PKG=${i##*/};
    PACKAGE=$(echo $PKG|sed 's/\([a-z-]*\)-[0-9].*/\1/');
    echo "${PACKAGES[*]}"|grep -qw "$PACKAGE" || PACKAGES+=($PACKAGE);
done

# echo "==============";
# for i in ${!PACKAGES[*]};do
#     echo "$i: ${PACKAGES[$i]}";
# done
# exit
CURRENT_PACKAGE=${PACKAGES[0]}

################################################################
# mark the stages with version we working on

DO_MARK_VERSION(){
    PACKAGE="$1"
    VER="$2"
    
    # Mark the stages where the package is current
    for j in $(seq 0 $((${#PKG_LINES[*]}-1)));do
	PACKAGE=$(echo ${PKG_LINES[$j]}|cut -d, -f1)
	STAGE=$(echo ${PKG_LINES[$j]}|cut -d, -f2)
	VER=$(echo ${PKG_LINES[$j]}|cut -d, -f3)
	
	if [ "$VER" == "${MAXVER[$PACKAGE]}" ];then
	    LATEST="<===="
	    PKGSTAGE["$PACKAGE"]="$STAGE $VER"
	else
            LATEST=" "
        fi
    done
} # DO_MARK_VERSION

################################################################
# Go over each package and find available version(s)
#
DO_COLLECT_VERSIONS(){
    unset PKGSTAGE
    declare -gA PKGSTAGE
    unset PKG_LINES
    declare -gA PKG_LINES
    unset MAXVER
    declare -gA MAXVER
    unset PKGVERSIONS
    declare -gA PKGVERSIONS

    MAXPKGLEN=0
    MAXSTAGELEN=0
    MAXVERLEN=0
    
    for i in ${!PACKAGES[*]};do
	PACKAGE=${PACKAGES[$i]}
	[ $MAXPKGLEN -lt ${#PACKAGE} ] && MAXPKGLEN=${#PACKAGE}

        # round1, collect info
	for j in ${!STAGES[*]};do
            for codename in ${OS_CODENAME};do
	        [ ! -d ${DIRPATH}/${codename}/${STAGES[j]}/binary-all ] && echo "      ERROR: ${DIRPATH}/${codename}/${STAGES[j]}/binary-all is not a directory" && exit #continue
	        #[ ! -d ${DIRPATH}/${codename}/${STAGES[j]}/binary-all ] && continue
	        STAGE="${STAGES[j]}"
	        [ $MAXSTAGELEN -lt ${#STAGE} ] && MAXSTAGELEN=${#STAGE}

	        #Get version of the package
	        VER="$(dpkg -I $(ls ${DIRPATH}/${codename}/$STAGE/binary-all/$PACKAGE* 2>/dev/null|sort --version-sort|tail -1) 2>/dev/null|awk '/Version/{print $2}')"
                if [ -z "$VER" ];then
                    if [ "$PACKAGE" == "ba-test" ];then
                        #For testing
                        VER=$(ls ${DIRPATH}/${codename}/$STAGE/binary-all/$PACKAGE* 2>/dev/null |sed "s/.*$PACKAGE-//;s/.deb//"|sort --version-sort|tail -1)
                    fi
                fi
                if [ -z "$VER" ];then
                    VER=NA
                else
	            #check if it's the higest we have for this package
	            MAXVER[$PACKAGE]=$(echo "${MAXVER[$PACKAGE]} $VER"|xargs -n1|sort --version-sort|tail -1)
	            [ $MAXVERLEN -lt ${#VER} ] && MAXVERLEN=${#VER}
                fi

	        PKG_LINES[${#PKG_LINES[@]}]="$PACKAGE,$STAGE,$VER"
                if ! echo "${PKGVERSIONS[$PACKAGE]}"|grep -q "$VER ";then
                    PKGVERSIONS[$PACKAGE]+="$VER "
                fi
	    done
        done
        PKGVERSIONS[$PACKAGE]="$(echo ${PKGVERSIONS[$PACKAGE]}|xargs -n1|sort --version-sort|xargs)"
        DO_MARK_VERSION $PACKAGE ${MAXVER[$PACKAGE]} 
    done

} # DO_COLLECT_VERSIONS

################################################################
#
DO_SHOW_VERSIONS(){

    for i in ${!PKGSTAGE[*]};do
	printf "%-${MAXPKGLEN}s:   %${MAXSTAGELEN}s = %s\n" $i ${PKGSTAGE[$i]}
    done
    echo

    #unset PPACKAGE
    echo "Package: $CURRENT_PACKAGE"
    stage_level=0
    for j in $(seq 0 $((${#PKG_LINES[*]}-1)));do
	#echo " >>>>>>>>>>>>>>>>  $j - ${PKG_LINES[$j]}|"
	PACKAGE=$(echo ${PKG_LINES[$j]}|cut -d, -f1)
        [ "$PACKAGE" != "$CURRENT_PACKAGE" ] && continue
	STAGE=$(echo ${PKG_LINES[$j]}|cut -d, -f2)
	VER=$(echo ${PKG_LINES[$j]}|cut -d, -f3)

	let stage_level++
	if [ "$VER" == "${MAXVER[$PACKAGE]}" ];then
	    LATEST="<===="
	else
            LATEST=" "
        fi
	#echo "   >>>>>  %-${MAXPKGLEN}s  %${MAXSTAGELEN}s  %s"
	#echo "     >>>>>  ${PKG_LINES[$j]}"
	#printf "  %2d-%-${MAXSTAGELEN}s: %${MAXVERLEN}s %s\n" $stage_level $STAGE $VER "$LATEST"
	printf "  %-${MAXSTAGELEN}s: %${MAXVERLEN}s %s\n" $STAGE $VER "$LATEST"
    done

} # DO_SHOW_VERSIONS

################################################################
#

DO_MENU(){
    RESULT_FILE=$1

    DO_COLLECT_VERSIONS
    MSG="$(DO_SHOW_VERSIONS)"
    State=$(echo "$MSG"|sed 's/$/\\n/g')
    MAXLEN=0

    while read line;do
	[ -n "$DEBUG" ] && echo ">>>>>>MAXLEN=$MAXLEN, len=${#line}, line=>$line<"
	[ ${#line} -gt $MAXLEN ] && MAXLEN=${#line}
    done <<< "$(echo "$MSG")"
    MWIDTH=$(($MAXLEN+10))
    LINES=$(echo "$MSG"|wc -l)

    OPTIONS=("0" "exit")
    OPTIONS+=("1" "package")
    OPTIONS+=("2" "version")
    MCNT=3
    ALT=":"
    PACKAGE=$CURRENT_PACKAGE
    OPTIONS+=("$MCNT" "Decrease $PACKAGE")
    ALT+="$MCNT:"
    let MCNT++
    OPTIONS+=("$MCNT" "Increase $PACKAGE")
    ALT+="$MCNT:"
    let MCNT++

    MHEIGHT=$(($LINES+$MCNT+6))
    if [ -n "$DEBUG" ];then
	echo "OPTIONS=${OPTIONS[*]}"
	echo MHEIGHT=$MHEIGHT
	echo MWIDTH=$MWIDTH
        echo MAXSTAGELEN=$MAXSTAGELEN
	echo MCNT=$MCNT
	return
    fi

    #    RESULT_FILE=$(mktemp -t set_stage_XXXXXXXX)
    dialog --backtitle "Staging status and changes" \
	   --title "action" \
	   --menu "$State\n" $MHEIGHT $MWIDTH $MCNT \
	   "${OPTIONS[@]}" 2>$RESULT_FILE

    save_rc=$?
    [ $save_rc -ne 0 ] && echo "ERROR: $save_rc" >>$RESULT_FILE
    return $save_rc
} # DO_MENU

################################################################
# select what package to work on
DO_MENU_PACKAGE(){
    State="    Select package to work with"
    OPTIONS=("0" "return to main menu")
    MCNT=1
    MAXLEN=${#State}
    ALT=":"
    for i in ${!PACKAGES[*]};do
        OPTIONS+=("$MCNT" ${PACKAGES[$i]})
        ALT+="$MCNT:"
        let MCNT++
        LEN=$((${PACKAGES[$i]}+4))
        [ $LEN -gt $MAXLEN ] && MAXLEN=$LEN
    done

    MWIDTH=$(($MAXLEN+10))
    LINES=$(echo "$State"|wc -l)
    MHEIGHT=$(($LINES+$MCNT+10))
    dialog --backtitle "Select Package" \
	   --title "package" \
	   --menu "$State\n" $MHEIGHT $MWIDTH $MCNT \
	   "${OPTIONS[@]}" 2>$RESULT_FILE
    ACTION=$(<$RESULT_FILE)
    MENU="main"

    clear
    if [ "$ACTION" == "0" ];then
       return
    elif echo ":$ALT:"|grep -q ":$ACTION:";then
	    TaskNo=$(($ACTION*2+1))
	    CURRENT_PACKAGE=${OPTIONS[$TaskNo]}
    fi

    return 100
} # DO_MENU_PACKAGE

################################################################
# select what version to work on
DO_MENU_VERSION(){
    MENU="main"
    return 100
} # DO_MENU_VERSION

################################################################
#
DO_CHANGE_STAGE(){
    DIR="$1"  # Increase or Decrease
    WHAT="$2" # package name

    PKG_INFO="${PKGSTAGE[$WHAT]}"
    PKG_STAGE=$(echo "$PKG_INFO"|awk '{print $1}')
    PKG_VER=$(echo "$PKG_INFO"|awk '{print $2}')
    unset CMD

    for codename in ${OS_CODENAME};do
        #    echo "DIRPATH=${DIRPATH}/${codename}" >>/tmp/q
        PKGPATH=${DIRPATH}/${codename}/$PKG_STAGE/binary-all/$WHAT-$PKG_VER.deb

        for i in ${!STAGES[*]};do
	    [ "${STAGES[i]}" == $PKG_STAGE ] && break
        done

        if [[ "$DIR" =~ ^D ]];then
	    [ $i -ge 1 ] && CMD="rm -fv $PKGPATH ${DIRPATH}/${codename}/$PKG_STAGE/binary-all/Packages.gz" || CMD="# already first level, nothing to do"
        elif [[ "$DIR" =~ ^I ]];then
	    NEWPKGDIR=${DIRPATH}/${codename}/${STAGES[$(($i+1))]}/binary-all
	    NEWPKGPATH=$NEWPKGDIR/$WHAT-$PKG_VER.deb
	    if [ $i -lt $((${#STAGES[*]}-1)) ];then
                CMD=("cp -av $PKGPATH $NEWPKGPATH" "rm -fv ${DIRPATH}/${codename}/$PKG_STAGE/binary-all/Packages.gz $NEWPKGDIR/Packages.gz")
            else
                CMD="# already last level, nothing to do"
            fi
        else
	    DEB+="ERRROR, unknown direction:$DIR"
        fi
    done

    unset RESULT
    unset CMDD
    for i in ${!CMD[*]};do
        CMDD+="${CMD[i]}\n"
        RESULT="$RESULT\n$(eval ${CMD[i]} 2>&1)"
    done

    MSG="$(echo -e "${CMDD}$RESULT")"
    MAXLEN=0

    while read line;do
	[ ${#line} -gt $MAXLEN ] && MAXLEN=${#line}
    done <<< "$(echo "$MSG")"

    MWIDTH=$(($MAXLEN+10))
    LINES=$(echo "$MSG"|wc -l)
    MHEIGHT=$(($LINES+6))
    MSG=$(echo "$MSG"|sed 's/$/\\n/g;s/\;/\\n/g')
    dialog --msgbox "$MSG\n"  $MHEIGHT $MWIDTH

    return 0
} # DO_CHANGE_STAGE


#Mostly debug/verify
if [ "$1" == "--help" ];then
    echo "this options are mostly for verification/debugging"
    echo "$0 --show-path"
    echo "$0 --show-versions"
    exit
elif [ "$1" == "--show-path" ];then
    echo "Staging directories:"
    SPACES="$(printf -- ' %.0s' {1..255})"
    PREFIX=""
    for i in ${!STAGES[*]};do
        for codename in ${OS_CODENAME};do
            echo "  $PREFIX${DIRPATH}/${codename}/${STAGES[i]}"
            [ ! -d ${DIRPATH}/$codename/${STAGES[i]} ] && echo "      ERROR: ${DIRPATH}/${codename}/${STAGES[i]} is not a directory"
            PREFIX="${SPACES:0:$(($i*2))}\`-> "
        done
    done
    echo

    echo "Packages:"
    for i in ${!PACKAGES[*]};do
        echo "  ${PACKAGES[i]}"
    done
    echo

    echo "================================================================"
    exit
elif [ "$1" == "--show-versions" ];then
    DO_COLLECT_VERSIONS

    for PACKAGE in ${PACKAGES[*]};do
        echo "================"
        # echo "PACKAGE=$PACKAGE"
        # echo values=${PKGVERSIONS[*]}
        # echo "=="
        # echo index=${!PKGVERSIONS[*]}
        # echo "=="
        echo "PKGVERSIONS for $PACKAGE"
        PKGVERSIONS[$PACKAGE]="$(echo ${PKGVERSIONS[$PACKAGE]}|xargs -n1|sort --version-sort|xargs)"
        for i in ${PKGVERSIONS[$PACKAGE]};do
            echo "$i"
            #echo "$i: ${PKGVERSIONS[$i]}"
        done
    done

    echo "****************************************************************"
    echo "show lines"
    # echo "===="
    # echo ${PKG_LINES[*]}
    # echo "===="
    # echo ${!PKG_LINES[*]}
    # echo "===="
    # echo ${#PKG_LINES[*]}
    # echo "===="

    for line in $(seq 0 $((${#PKG_LINES[*]}-1)));do
        echo "$line: ${PKG_LINES[$line]}"
    done

    echo end of PKG_LINES
    echo "================================================================"
    exit
fi

#exit
#TODO:
#  use dialog to give a small menu
#   base on stage or package
#  allow multiple versions

if [ -n "$DEBUG" ];then
    clear
    DO_MENU
    exit
fi


MENU="main"

while true;do
    clear
    #ACTION=$(DO_MENU)
    #RESULT_FILE=$(mktemp -t set_stage_XXXXXXXX)
    
    RESULT_FILE=/tmp/resultfile
    if [ "$MENU" == "main" ];then
        DO_MENU  $RESULT_FILE
        save_rc=$?
        #echo -e "================"
        ACTION=$(<$RESULT_FILE)
        if [ "$ACTION" == "0" ];then
	    clear
            ${0%/*}/update_repo_data.sh
	    echo "Thank you and goodbye"
	    exit
        elif [ "$ACTION" == "1" ];then
            MENU=package
        elif [ "$ACTION" == "2" ];then
            MENU=version            
        elif echo ":$ALT:"|grep -q ":$ACTION:";then
	    TaskNo=$(($ACTION*2+1))
	    DO_CHANGE_STAGE ${OPTIONS[$TaskNo]}
        elif [ $save_rc -eq 1 ];then # selected "cancel"
            dialog --infobox "\n    action cancelled"  5 30
            exit
        elif [ $save_rc -eq 255 ];then # hit escape
            dialog --infobox "\n  <esc> - action aborted"  5 30
            exit
        else
	    dialog --infobox "Unknown action: $ACTION\nsave_rc=$save_rc"  10 30
	    exit
        fi
    elif [ "$MENU" == "package" ];then
        DO_MENU_PACKAGE $RESULT_FILE
        save_rc=$?
    elif [ "$MENU" == "version" ];then
        DO_MENU_VERSION $RESULT_FILE
        save_rc=$?
        ACTION=$(<$RESULT_FILE)
    fi
done
