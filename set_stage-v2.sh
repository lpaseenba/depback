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
	
	if [ "$VER" == "${CURRENT_VERSION}" ];then
	    LATEST="<===="
	    PKGSTAGE["$PACKAGE"]="$STAGE $VER"  # The highest stage that this version exist on
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

    unset PKGVERS
    declare -gA PKGVERS

    MAXPKGLEN=0
    MAXSTAGELEN=0
    MAXVERLEN=0
    
    for i in ${!PACKAGES[*]};do
	PACKAGE=${PACKAGES[$i]}
	[ $MAXPKGLEN -lt ${#PACKAGE} ] && MAXPKGLEN=${#PACKAGE}

        CURRENT_STAGE=""
        for codename in ${OS_CODENAME};do
            for j in ${!STAGES[*]};do
	        STAGE="${STAGES[$j]}"
	        [ ! -d ${DIRPATH}/${codename}/$STAGE/binary-all ] && echo "      ERROR: ${DIRPATH}/${codename}/${STAGES[j]}/binary-all is not a directory" && exit #continue
	        [ $MAXSTAGELEN -lt ${#STAGE} ] && MAXSTAGELEN=${#STAGE}
                for PKGVER in $(ls ${DIRPATH}/${codename}/$STAGE/binary-all/$PACKAGE* 2>/dev/null|sort --version-sort --reverse|head -10);do
                    PKGNAME=${PKGVER##*/}
                    #use a version cache in PKGVERS so we don't do dpkg multiple times for same package name
                    if [ -n "${PKGVERS[$PKGNAME]}" ];then 
                        VER=${PKGVERS[$PKGNAME]}
                    else
                        #Get version of the package
	                VER="$(dpkg -I $PKGVER 2>/dev/null|awk '/Version/{print $2}'|tr -d ' ')"
                        if [ -z "$VER" ];then
                            if [ "$PACKAGE" == "ba-test" ];then
                                #For testing
                                VER=$(echo $PKGVER|sed "s/.*$PACKAGE-//;s/.deb//"|sort --version-sort|tail -1)
                            fi
                        fi
                        PKGVERS[$PKGNAME]=$VER
                    fi

                    if [ -z "$VER" ];then
                        VER=NA
                    else
                        [ -z "${MAXVER[$PACKAGE]}" ] && MAXVER[$PACKAGE]=$VER # the first version is always the highest due to --version-sort
	                [ $MAXVERLEN -lt ${#VER} ] && MAXVERLEN=${#VER}
                    fi

                    if [ "$CURRENT_STAGE" != "$STAGE" ];then
                        PKG_LINES[${#PKG_LINES[@]}]="$PACKAGE,$STAGE,$VER"
                        CURRENT_STAGE="$STAGE"
                    fi

                    if [ "$VER" != "NA" ];then
                        if ! echo "${PKGVERSIONS[$PACKAGE]}"|grep -q "$VER ";then
                            PKGVERSIONS[$PACKAGE]+="$VER "
                        fi
                    fi
                done
	    done
        done

        PKGVERSIONS[$PACKAGE]="$(echo ${PKGVERSIONS[$PACKAGE]}|xargs -n1|sort --version-sort --reverse|xargs)"
        [ -z "$CURRENT_VERSION" ] && CURRENT_VERSION=${MAXVER[$CURRENT_PACKAGE]}
        DO_MARK_VERSION $PACKAGE $CURRENT_VERSION
    done

} # DO_COLLECT_VERSIONS

################################################################
#
DO_SHOW_VERSIONS(){

    # for i in ${!PKGSTAGE[*]};do
    #     printf "%-${MAXPKGLEN}s:   %${MAXSTAGELEN}s = %s\n" $i ${PKGSTAGE[$i]}
    # done
    # echo

    # https://linux.die.net/man/1/dialog
    # \Z0 through 7 are the ANSI used in curses: black, red, green, yellow, blue, magenta, cyan and white respectively
    # Bold is set by 'b', reset by 'B'
    # Reverse is set by 'r', reset by 'R'.
    # Underline is set by 'u', reset by 'U'.
    # The settings are cumulative, e.g., "\Zb\Z1" makes the following text bold (perhaps bright) red.
    # Restore normal settings with "\Zn".
    bold="\Z3\Zb"
    normal="\Zn"

    #unset PPACKAGE
    echo -e "\n  Package: ${bold}$CURRENT_PACKAGE${normal} - ${bold}${CURRENT_VERSION}${normal}\n"
    CURRENT_STAGE=""
    for j in $(seq 0 $((${#PKG_LINES[*]}-1)));do
	#echo " >>>>>>>>>>>>>>>>  $j - ${PKG_LINES[$j]}|"
	PACKAGE=$(echo ${PKG_LINES[$j]}|cut -d, -f1)
        [ "$PACKAGE" != "$CURRENT_PACKAGE" ] && continue
	STAGE=$(echo ${PKG_LINES[$j]}|cut -d, -f2)
        [ "$CURRENT_STAGE" == "$STAGE" ] && continue
        CURRENT_STAGE="$STAGE"
	VER=$(echo ${PKG_LINES[$j]}|cut -d, -f3)

	if [ "$VER" == "$CURRENT_VERSION" ];then
	    CURRENT="<===="
	else
            CURRENT=" "
        fi

	printf "  %-${MAXSTAGELEN}s: %-${MAXVERLEN}s %s\n" $STAGE "$VER" "$CURRENT"
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
    OPTIONS+=("$MCNT" "Decrease $PACKAGE $VERSION")
    ALT+="$MCNT:"
    let MCNT++
    OPTIONS+=("$MCNT" "Increase $PACKAGE $VERSION")
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
           --colors \
	   --menu "$State\n" $MHEIGHT $MWIDTH $MCNT \
	   "${OPTIONS[@]}" 2>$RESULT_FILE

    save_rc=$?
    [ $save_rc -ne 0 ] && echo "ERROR: $save_rc" >>$RESULT_FILE
    return $save_rc
} # DO_MENU

################################################################
# select what package to work on
DO_MENU_PACKAGE(){

    PState="    Select package to work with"
    POPTIONS=("0" "return to main menu")
    PMCNT=1
    PMAXLEN=${#PState}
    ALT=":"
    for i in ${!PACKAGES[*]};do
        POPTIONS+=("$PMCNT" ${PACKAGES[$i]})
        ALT+="$PMCNT:"
        let PMCNT++
        LEN=$((${#PACKAGES[$i]}+4))
        [ $LEN -gt $MAXLEN ] && MAXLEN=$LEN
    done

    PMWIDTH=$(($PMAXLEN+10))
    PLINES=$(echo "$PState"|wc -l)
    PMHEIGHT=$(($PLINES+$PMCNT+10))

#	   --menu "$State\n" $MHEIGHT $MWIDTH $MCNT \
#	   "${OPTIONS[@]}" \
#           --and-widget --begin 40 40 \
    dialog --backtitle "Select Package" \
	   --title "package" \
	   --menu "$PState\n" $PMHEIGHT $PMWIDTH $PMCNT \
	   "${POPTIONS[@]}" 2>$RESULT_FILE
    save_rc=$?
    if [ $save_rc -eq 0 ];then
        ACTION=$(<$RESULT_FILE)
        MENU="main"

        if [ "$ACTION" == "0" ];then
            return
        elif echo ":$ALT:"|grep -q ":$ACTION:";then
	    TaskNo=$(($ACTION*2+1))
	    CURRENT_PACKAGE=${POPTIONS[$TaskNo]}
            CURRENT_VERSION=${MAXVER[$CURRENT_PACKAGE]}
        fi
    fi

    return $save_rc
} # DO_MENU_PACKAGE

################################################################
# select what version to work on
DO_MENU_VERSION(){

    VState="    Select version to work with"
    VOPTIONS=("0" "return to main menu")
    VMCNT=1
    VMAXLEN=${#VState}
    ALT=":"

    for i in ${PKGVERSIONS[$PACKAGE]};do
        VOPTIONS+=("$VMCNT" $i)
        ALT+="$VMCNT:"
        let VMCNT++
        LEN=$((${#i}+4))
        [ $LEN -gt $MAXLEN ] && MAXLEN=$LEN
    done

    VMWIDTH=$(($VMAXLEN+10))
    VLINES=$(echo "$VState"|wc -l)
    VMHEIGHT=$(($VLINES+$VMCNT+10))

    dialog --backtitle "Select Version for $CURRENT_PACKAGE" \
	   --title "version" \
	   --menu "$VState\n" $VMHEIGHT $VMWIDTH $VMCNT \
	   "${VOPTIONS[@]}" 2>$RESULT_FILE
    save_rc=$?
    if [ $save_rc -eq 0 ];then
        ACTION=$(<$RESULT_FILE)
        MENU="main"

        if [ "$ACTION" == "0" ];then
            return
        elif echo ":$ALT:"|grep -q ":$ACTION:";then
	    TaskNo=$(($ACTION*2+1))
            CURRENT_VERSION=${VOPTIONS[$TaskNo]}
        fi
    fi

    return $save_rc
} # DO_MENU_VERSION

################################################################
#
DO_CHANGE_STAGE(){
    DIR="$1"  # Increase or Decrease

    unset CMD

    for codename in ${OS_CODENAME};do
        # find last stage that it currently exist at
        for i in ${!STAGES[*]};do
            CANDIDATE=${DIRPATH}/${codename}/${STAGES[i]}/binary-all/$CURRENT_PACKAGE-$CURRENT_VERSION.deb
            [ -e  $CANDIDATE ] && PKGPATH=$CANDIDATE && PKG_STAGE=${STAGES[i]} && STAGE_LEVEL=$i
        done

        if [[ "$DIR" =~ ^D ]];then # direction = decrease
	    if [ $STAGE_LEVEL -ge 1 ];then
                if [ -n "$PKG_STAGE" -a -d ${DIRPATH}/${codename}/$PKG_STAGE/ ];then
                    CMD="rm -fv $PKGPATH ${DIRPATH}/${codename}/$PKG_STAGE/binary-all/Packages.gz"
                else
                    CMD="# No level to go down from for $CURRENT_PACKAGE $CURRENT_VERSION"
                fi
            else
                CMD="# already first level, nothing to do for $CURRENT_PACKAGE $CURRENT_VERSION"
            fi
        elif [[ "$DIR" =~ ^I ]];then # direction = increase
            if [ -n "$PKG_STAGE" ];then
	        if [ $STAGE_LEVEL -lt $((${#STAGES[*]}-1)) ];then
	            NEWPKGDIR=${DIRPATH}/${codename}/${STAGES[$(($STAGE_LEVEL+1))]}/binary-all
	            NEWPKGPATH=$NEWPKGDIR/$CURRENT_PACKAGE-$CURRENT_VERSION.deb
                    CMD=("cp -av $PKGPATH $NEWPKGPATH" "rm -fv ${DIRPATH}/${codename}/$PKG_STAGE/binary-all/Packages.gz $NEWPKGDIR/Packages.gz")
                else
                    CMD="# already last level, nothing to do for $PKG_INFO ($CURRENT_PACKAGE)"
                fi
            else
                # if [ ! -e  ${DIRPATH}/${codename}/${STAGES[$STAGE_LEVEL]}/binary-all/$CURRENT_PACKAGE-$CURRENT_VERSION.deb ];then
                #     NEWPKGDIR=${DIRPATH}/${codename}/${STAGES[$(($STAGE_LEVEL))]}/binary-all
                #     NEWPKGPATH=$NEWPKGDIR/$CURRENT_PACKAGE-$CURRENT_VERSION.deb
	        #     if [ $STAGE_LEVEL -lt $((${#STAGES[*]}-1)) ];then
                #         CMD=("cp -av $PKGPATH $NEWPKGPATH" "rm -fv ${DIRPATH}/${codename}/$PKG_STAGE/binary-all/Packages.gz $NEWPKGDIR/Packages.gz")
                #     else
                #         CMD="# already last level, nothing to do for $PKG_INFO ($CURRENT_PACKAGE)"
                #     fi
                # else
                CMD="# No level found for $CURRENT_PACKAGE-$CURRENT_VERSION"
                # fi
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
if [ "$1" == "--show-path" ];then
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
    #CURRENT_PACKAGE=ba-btm-test
    #CURRENT_VERSION=0.0-4.0xenial16
    #DO_COLLECT_VERSIONS

    #CURRENT_PACKAGE=ba-btm-software
    #CURRENT_VERSION=0.0-4.0xenial16

    DO_COLLECT_VERSIONS

    for PACKAGE in ${PACKAGES[*]};do
        echo "================"
        # echo "PACKAGE=$PACKAGE"
        # echo values=${PKGVERSIONS[*]}
        # echo "=="
        # echo index=${!PKGVERSIONS[*]}
        # echo "=="
        echo "PKGVERSIONS for $PACKAGE"
        for i in ${PKGVERSIONS[$PACKAGE]};do
            echo "$i"
            #echo "$i: ${PKGVERSIONS[$i]}"
        done
    done

    echo "****************************************************************"
    echo "show PKG_LINES"
    # echo "===="
    # echo ${PKG_LINES[*]}
    # echo "===="
    # echo ${!PKG_LINES[*]}
    # echo "===="
    # echo ${#PKG_LINES[*]}
    # echo "===="

    for line in $(seq 0 $((${#PKG_LINES[*]}-1)));do
        #printf "%2d: %s\n" "$line" "${PKG_LINES[$line]}"
        printf "%20s  %-12s %-25s \n" $(echo ${PKG_LINES[$line]}|tr ',' ' ')
    done

    echo end of PKG_LINES
    echo "================================================================"

    echo "****************************************************************"
    echo " PKGSTAGE"
    # echo "===="
    # echo ${PKGSTAGE[*]}
    # echo "===="
    # echo ${!PKGSTAGE[*]}
    # echo "===="
    # echo ${#PKGSTAGE[*]}
    # echo "===="

    #for line in $(seq 0 $((${#PKGSTAGE[*]}-1)));do
    for line in ${!PKGSTAGE[*]};do
        printf "%20s: %s\n" "$line" "${PKGSTAGE[$line]}"
    done

    echo end of PKGSTAGE
    echo "================================================================"

    exit
elif [ "$1" == "--show-state" -o "$1" == "--show-stages" ];then

    DO_COLLECT_VERSIONS
    PREVPKG=""
    date +%F\ %T
    for line in $(seq 0 $((${#PKG_LINES[*]}-1)));do
        PKG=$(echo ${PKG_LINES[$line]}|cut -d, -f1)
        STAGE=$(echo ${PKG_LINES[$line]}|cut -d, -f2)
        VERSION=$(echo ${PKG_LINES[$line]}|cut -d, -f3)
        [ "$PKG" != "$PREVPKG" ] && echo "$PKG:" && PREVPKG=$PKG
        printf " %-12s %-25s \n" $STAGE $VERSION
    done
    exit
#elif [ "$1" == "--help" ];then
elif [ -n "$1" ];then
    echo "this options are mostly for verification/debugging"
    echo "$0 --show-path"
    echo "$0 --show-versions"
    echo "$0 --show-stages"
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
    #ACTION=$(DO_MENU)
    #RESULT_FILE=$(mktemp -t set_stage_XXXXXXXX)
    
    RESULT_FILE=/tmp/resultfile
    if [ "$MENU" == "main" ];then
        clear
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
        if [ $save_rc -eq 1 ];then # selected "cancel"
            dialog --infobox "\n    action cancelled"  5 30
            exit
        elif [ $save_rc -eq 255 ];then # hit escape
            dialog --infobox "\n  <esc> - action aborted"  5 30
            exit
        fi
    elif [ "$MENU" == "version" ];then
        DO_MENU_VERSION $RESULT_FILE
        save_rc=$?
        if [ $save_rc -eq 1 ];then # selected "cancel"
            dialog --infobox "\n    action cancelled"  5 30
            exit
        elif [ $save_rc -eq 255 ];then # hit escape
            dialog --infobox "\n  <esc> - action aborted"  5 30
            exit
        fi
    fi
done
