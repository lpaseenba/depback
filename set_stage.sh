#!/bin/bash
#Purpose: show what stage any given package is at
#
#



DIRPATH=/var/www/html/bitaccess

STAGES=($(echo {development,qa,staging,release/stage{1..5}}))
PACKAGES=("docker_cloud_btm" "provisioner")

if false;then
echo "Staging directories:"
SPACES="$(printf -- ' %.0s' {1..255})"
PREFIX=""
for i in ${!STAGES[*]};do
    echo "  $PREFIX${STAGES[i]}"
    [ ! -d ${STAGES[i]} ] && echo "      ERROR: ${STAGES[i]} is not a directory"
    PREFIX="${SPACES:0:$(($i*2))}\`-> "
done
echo

echo "Packages:"
for i in ${!PACKAGES[*]};do
    echo "  ${PACKAGES[i]}"
done
echo

echo "================================================================"
fi


################################################################
#
DO_COLLECT_VERSIONS(){
    unset PKGSTAGE
    declare -gA PKGSTAGE
    unset LINES
    declare -gA LINES
    
    MAXPKGLEN=0
    MAXSTAGELEN=0
    MAXVERLEN=0
    
    for i in ${!PACKAGES[*]};do
	PACKAGE=${PACKAGES[$i]}
	[ $MAXPKGLEN -lt ${#PACKAGE} ] && MAXPKGLEN=${#PACKAGE}

	unset MAXVER
	# round1, collect info
	for j in ${!STAGES[*]};do
	    #[ ! -d $DIRPATH/${STAGES[j]} ] && echo "      ERROR: ${STAGES[j]} is not a directory" && continue
	    [ ! -d $DIRPATH/${STAGES[j]} ] && continue
	    STAGE="${STAGES[j]}"
	    [ $MAXSTAGELEN -lt ${#STAGE} ] && MAXPSTAGELEN=${#STAGE}

	    #Get version of the package
	    VER="$(dpkg -I $(ls $DIRPATH/$STAGE/$PACKAGE*|sort --version-sort|tail -1)|awk '/Version/{print $2}')"

	    #check if it's the higest we have for this package
	    MAXVER=$(echo "$MAXVER $VER"|xargs -n1|sort --version-sort|tail -1)
	    [ $MAXVERLEN -lt ${#VER} ] && MAXVERLEN=${#VER}

	    LINES[${#LINES[*]}]="$PACKAGE,$STAGE,$VER"
	done
	
	#round2 - find max version of the package
	for j in $(seq 0 $((${#LINES[*]}-1)));do
	     PACKAGE=$(echo ${LINES[$j]}|cut -d, -f1)
	     STAGE=$(echo ${LINES[$j]}|cut -d, -f2)
	     VER=$(echo ${LINES[$j]}|cut -d, -f3)
	    
	     if [ "$VER" == "$MAXVER" ];then
	 	LATEST="<===="
	 	PKGSTAGE["$PACKAGE"]="$STAGE $VER"
	     else
                 LATEST=" "
             fi
	 done
    done

} # DO_COLLECT_VERSIONS

################################################################
#
DO_SHOW_VERSIONS(){
    
#    for i in ${!PACKAGES[*]};do
#	PACKAGE=${PACKAGES[$i]}

    unset PPACKAGE
    for j in $(seq 0 $((${#LINES[*]}-1)));do
	#echo " >>>>>>>>>>>>>>>>  $j - ${LINES[$j]}|"
	PACKAGE=$(echo ${LINES[$j]}|cut -d, -f1)
	STAGE=$(echo ${LINES[$j]}|cut -d, -f2)
	VER=$(echo ${LINES[$j]}|cut -d, -f3)
	
	if [ "$PPACKAGE" != "$PACKAGE" ];then
	    [ -n "$PPACKAGE" ] && echo
	    echo "Package: $PACKAGE"
	    PPACKAGE=$PACKAGE
	    stage_level=0
	fi

	let stage_level++
	if [ "$VER" == "$MAXVER" ];then
	    LATEST="<===="
	else
            LATEST=" "
        fi
	#echo "   >>>>>  %-${MAXPKGLEN}s  %${MAXPSTAGELEN}s  %s"
	#echo "     >>>>>  ${LINES[$j]}"
	#printf "  %2d-%-${MAXPSTAGELEN}s: %${MAXVERLEN}s %s\n" $stage_level $STAGE $VER "$LATEST"
	printf "  %-${MAXPSTAGELEN}s: %${MAXVERLEN}s %s\n" $STAGE $VER "$LATEST"
    done
    echo
    
    for i in ${!PKGSTAGE[*]};do
	printf "%-${MAXPKGLEN}s:   %${MAXPSTAGELEN}s = %s\n" $i ${PKGSTAGE[$i]}
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
    MCNT=1
    ALT=":"
    for i in ${!PACKAGES[*]};do
	PACKAGE=${PACKAGES[$i]}
	OPTIONS+=("$MCNT" "Decrease $PACKAGE")
	ALT+="$MCNT:"
	let MCNT++
	OPTIONS+=("$MCNT" "Increase $PACKAGE")
	ALT+="$MCNT:"
	let MCNT++
    done

    MHEIGHT=$(($LINES+$MCNT+6))
    if [ -n "$DEBUG" ];then
	echo "OPTIONS=${OPTIONS[*]}"
	echo MHEIGHT=$MHEIGHT
	echo MWIDTH=$MWIDTH
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
} # DO_MENU


################################################################
#
DO_CHANGE_STAGE(){
    DIR="$1"  # Increase or Decrease
    WHAT="$2" # package name
    PKG_INFO="${PKGSTAGE[$WHAT]}"
    PKG_STAGE=$(echo "$PKG_INFO"|awk '{print $1}')
    PKG_VER=$(echo "$PKG_INFO"|awk '{print $2}')
    unset CMD
    
    #    echo "DIRPATH=$DIRPATH" >>/tmp/q
    PKGPATH=$DIRPATH/$PKG_STAGE/$WHAT-$PKG_VER.deb

    for i in ${!STAGES[*]};do
	[ "${STAGES[i]}" == $PKG_STAGE ] && break
    done

    if [[ "$DIR" =~ ^D ]];then
	[ $i -ge 1 ] && CMD="rm -fv $PKGPATH $DIRPATH/$PKG_STAGE/Packages.gz" || CMD="# already first level, nothing to do"
    elif [[ "$DIR" =~ ^I ]];then
	NEWPKGDIR=$DIRPATH/${STAGES[$(($i+1))]}
	NEWPKGPATH=$NEWPKGDIR/$WHAT-$PKG_VER.deb
	if [ $i -lt $((${#STAGES[*]}-1)) ];then
            CMD=("cp -av $PKGPATH $NEWPKGPATH" "rm -fv $DIRPATH/$PKG_STAGE/Packages.gz $NEWPKGDIR/Packages.gz")
        else
            CMD="# already last level, nothing to do"
        fi
    else
	DEB+="ERRROR, unknown direction:$DIR"
    fi

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

#TODO:
#  use dialog to give a small menu
#   base on stage or package
#   show what stage each package is at
#   show what is in each stage
#   move a package to next stage


if [ -n "$DEBUG" ];then
    clear
    DO_MENU
    exit
fi

#DO_COLLECT_VERSIONS
#DO_SHOW_VERSIONS
#exit

while true;do
    clear
    #ACTION=$(DO_MENU)
    #RESULT_FILE=$(mktemp -t set_stage_XXXXXXXX)
    RESULT_FILE=/tmp/resultfile
    DO_MENU  $RESULT_FILE
    #echo -e "================"
    ACTION=$(<$RESULT_FILE)
    if [ "$ACTION" == "0" ];then
	clear
        ${0%/*}/update_repo_data.sh
	echo "Thank you and goodbye"
	exit
    elif echo ":$ALT:"|grep -q ":$ACTION:";then
	TaskNo=$(($ACTION*2+1))
	DO_CHANGE_STAGE ${OPTIONS[$TaskNo]}
    else
	dialog --infobox "Unknown action: $ACTION\n"  10 30
	exit
    fi

    #echo "$ACTION"
    #echo "================"
    #rm -f $RESULT_FILE
done
