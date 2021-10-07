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

unset PKGSTAGE
declare -A PKGSTAGE

DO_SHOW_VERSIONS(){
    MAXPKGLEN=0
    MAXSTAGELEN=0
    MAXVERLEN=0
    for i in ${!PACKAGES[*]};do
	PACKAGE=${PACKAGES[$i]}
	
	echo "Package: $PACKAGE"
	[ $MAXPKGLEN -lt ${#PACKAGE} ] && MAXPKGLEN=${#PACKAGE}

	unset MAXVER
	unset LINES
	declare -A LINES
	# round1, collect info
	for j in ${!STAGES[*]};do
	    [ ! -d $DIRPATH/${STAGES[j]} ] && echo "      ERROR: ${STAGES[j]} is not a directory" && continue
	    STAGE="${STAGES[j]}"
	    [ $MAXSTAGELEN -lt ${#STAGE} ] && MAXPSTAGELEN=${#STAGE}
	    
	    #Get version of the package
	    VER="$(dpkg -I $(ls $DIRPATH/$STAGE/$PACKAGE*|sort --version-sort|tail -1)|awk '/Version/{print $2}')"
	    
	    #check if it's the higest we have for this package
	    MAXVER=$(echo "$MAXVER $VER"|xargs -n1|sort --version-sort|tail -1)
	    [ $MAXVERLEN -lt ${#VER} ] && MAXVERLEN=${#VER}
	    
	    LINES[${#LINES[*]}]="$PACKAGE,$STAGE,$VER"
	done

	#round2 - print it out
	for j in $(seq 0 $((${#LINES[*]}-1)));do
	    #echo " >>>>>>>>>>>>>>>>  $j - ${LINES[$j]}|"
	    PACKAGE=$(echo ${LINES[$j]}|cut -d, -f1)
	    STAGE=$(echo ${LINES[$j]}|cut -d, -f2)
	    VER=$(echo ${LINES[$j]}|cut -d, -f3)
	    
	    if [ "$VER" == "$MAXVER" ];then
		LATEST="<===="
		PKGSTAGE["$PACKAGE"]="$STAGE $VER"
	    else
                LATEST=" "
            fi
	    #echo "   >>>>>  %-${MAXPKGLEN}s  %${MAXPSTAGELEN}s  %s"
	    #echo "     >>>>>  ${LINES[$j]}"
	    printf "  %-${MAXPSTAGELEN}s: %${MAXVERLEN}s %s\n" $STAGE $VER "$LATEST"
	done
	echo
    done

    for i in ${!PKGSTAGE[*]};do
	printf "%-${MAXPKGLEN}s:   %${MAXPSTAGELEN}s = %s\n" $i ${PKGSTAGE[$i]}
    done
} # DO_SHOW_VERSIONS


#TODO:
#  use dialog to give a small menu
#   base on stage or package
#   show what stage each package is at
#   show what is in each stage
#   move a package to next stage

#menu1:
#  docker:
#    development: 0.13
#    stage5: 0.11
#


# ch=( "1" "Fri, 20/3/15" "2" "Sun, 21/6/15" "3" "Wed, 23/9/15" "4" "Mon, 21/12/15")


#dialog --title "Equinoxes and Solistices"  \
#--radiolist "When is the Winter Solictice?" 15 60 4 \
#"${ch[0]}" "${ch[1]}" ON \
#"${ch[2]}" "${ch[3]}" OFF \
#"${ch[4]}" "${ch[5]}" OFF \
#"${ch[6]}" "${ch[7]}" OFF >$TMPFILE



DO_SHOW_VERSIONS
#foo="$(DO_SHOW_VERSIONS)"
#echo "$foo"
